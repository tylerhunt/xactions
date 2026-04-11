defmodule Xactions.Budgeting do
  @moduledoc """
  Context for zero-based budget management.

  Implements YNAB-style TBB (To Be Budgeted) logic:
  - TBB = sum of Income-category transactions - sum of envelope allocations for the month
  - Envelopes: fixed (copy forward), variable (pre-fill from previous), rollover (carry balance)
  """

  import Ecto.Query

  alias Xactions.Repo
  alias Xactions.Budgeting.{BudgetEnvelope, BudgetMonth, EnvelopeCategory}
  alias Xactions.Transactions.{Transaction, Category}

  # --- TBB ---

  @doc """
  Returns the To Be Budgeted amount for the given month.
  TBB = total income transactions in the month - total allocations for the month
  """
  def to_be_budgeted(%Date{} = date) do
    income = total_income(date)
    allocated = total_allocated(date)
    Decimal.sub(income, allocated)
  end

  @doc "Returns the total income transactions for the given month."
  def total_income(%Date{} = date) do
    income_ids = income_category_ids()

    if income_ids == [] do
      Decimal.new("0")
    else
      result =
        Repo.one(
          from t in Transaction,
            where:
              t.category_id in ^income_ids and
                fragment("strftime('%Y', ?)", t.date) == ^Integer.to_string(date.year) and
                fragment("strftime('%m', ?)", t.date) == ^zero_padded(date.month),
            select: sum(t.amount)
        )

      result || Decimal.new("0")
    end
  end

  @doc "Returns the total allocated amount across all active envelopes for the given month."
  def total_allocated(%Date{} = date) do
    result =
      Repo.one(
        from bm in BudgetMonth,
          join: env in BudgetEnvelope,
          on: bm.budget_envelope_id == env.id,
          where:
            bm.month == ^date.month and bm.year == ^date.year and
              is_nil(env.archived_at),
          select: sum(bm.allocated_amount)
      )

    result || Decimal.new("0")
  end

  @doc "Returns the total spent across all active envelopes for the given month."
  def total_spent(%Date{} = date) do
    active_envelopes =
      Repo.all(
        from e in BudgetEnvelope,
          where: is_nil(e.archived_at),
          preload: [envelope_categories: []]
      )

    active_envelopes
    |> Enum.map(&envelope_spent(&1, date))
    |> Enum.reduce(Decimal.new("0"), &Decimal.add/2)
  end

  defp income_category_ids do
    Repo.all(
      from c in Category,
        where: like(fragment("LOWER(?)", c.name), "income"),
        select: c.id
    )
  end

  # --- Envelopes ---

  @doc """
  Lists all active (non-archived) envelopes for the given month with computed
  budgeted, spent, and remaining amounts.
  """
  def list_envelopes(%Date{} = date) do
    envelopes =
      Repo.all(
        from e in BudgetEnvelope,
          where: is_nil(e.archived_at),
          preload: [budget_months: ^budget_months_query(date), envelope_categories: :category],
          order_by: [asc: e.name]
      )

    Enum.map(envelopes, fn env ->
      bm =
        Enum.find(env.budget_months, fn bm ->
          bm.month == date.month && bm.year == date.year
        end)

      budgeted = (bm && bm.allocated_amount) || Decimal.new("0")
      spent = envelope_spent(env, date)
      remaining = Decimal.sub(budgeted, spent)

      env
      |> Map.put(:budgeted, budgeted)
      |> Map.put(:spent, spent)
      |> Map.put(:remaining, remaining)
    end)
  end

  defp budget_months_query(date) do
    from bm in BudgetMonth,
      where: bm.month == ^date.month and bm.year == ^date.year
  end

  defp envelope_spent(env, date) do
    cat_ids = Enum.map(env.envelope_categories, & &1.category_id)

    if cat_ids == [] do
      Decimal.new("0")
    else
      result =
        Repo.one(
          from t in Transaction,
            where:
              t.category_id in ^cat_ids and
                fragment("strftime('%Y', ?)", t.date) == ^Integer.to_string(date.year) and
                fragment("strftime('%m', ?)", t.date) == ^zero_padded(date.month),
            select: sum(t.amount)
        )

      # Spending is negative amounts; return absolute value
      raw = result || Decimal.new("0")
      if Decimal.negative?(raw), do: Decimal.negate(raw), else: raw
    end
  end

  @doc """
  Returns categories not assigned to any active (non-archived) envelope.

  Pass `except_envelope_id: id` to include categories belonging to a specific
  envelope (used when editing that envelope so its own categories remain selectable).
  """
  def list_available_categories(opts \\ []) do
    except_id = Keyword.get(opts, :except_envelope_id)

    assigned_ids =
      Repo.all(
        from ec in EnvelopeCategory,
          join: env in BudgetEnvelope,
          on: ec.budget_envelope_id == env.id,
          where: is_nil(env.archived_at),
          select: ec.category_id
      )

    excluded_ids =
      if except_id do
        own_ids =
          Repo.all(
            from ec in EnvelopeCategory,
              where: ec.budget_envelope_id == ^except_id,
              select: ec.category_id
          )

        assigned_ids -- own_ids
      else
        assigned_ids
      end

    Repo.all(
      from c in Category,
        where: c.id not in ^excluded_ids,
        order_by: [asc: c.name]
    )
  end

  @doc """
  Creates a new budget envelope.
  """
  def create_envelope(attrs) do
    %BudgetEnvelope{}
    |> BudgetEnvelope.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a new budget envelope and assigns the given category IDs atomically.
  Returns `{:error, :no_categories}` if `category_ids` is empty.
  """
  def create_envelope_with_categories(_attrs, []), do: {:error, :no_categories}

  def create_envelope_with_categories(attrs, category_ids) do
    Repo.transaction(fn ->
      case create_envelope(attrs) do
        {:ok, envelope} ->
          assign_all_categories(envelope, category_ids)
          envelope

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Updates an envelope's attributes and atomically replaces its category assignments.

  Deletes all existing `EnvelopeCategory` rows for the envelope and inserts new
  ones from `category_ids`. Both the update and the reassignment are wrapped in a
  single transaction.
  """
  def update_envelope(%BudgetEnvelope{} = envelope, attrs, category_ids) do
    Repo.transaction(fn ->
      changeset = BudgetEnvelope.changeset(envelope, attrs)

      case Repo.update(changeset) do
        {:ok, updated} ->
          Repo.delete_all(
            from ec in EnvelopeCategory, where: ec.budget_envelope_id == ^envelope.id
          )

          assign_all_categories(updated, category_ids)
          updated

        {:error, cs} ->
          Repo.rollback(cs)
      end
    end)
  end

  @doc """
  Marks an envelope as archived (soft delete).
  """
  def archive_envelope(%BudgetEnvelope{} = envelope) do
    envelope
    |> Ecto.Changeset.change(archived_at: DateTime.utc_now() |> DateTime.truncate(:second))
    |> Repo.update()
  end

  @doc """
  Sets or updates the allocation for an envelope in a given month.
  """
  def set_allocation(%BudgetEnvelope{} = envelope, %Date{} = date, amount) do
    case Repo.get_by(BudgetMonth,
           budget_envelope_id: envelope.id,
           month: date.month,
           year: date.year
         ) do
      nil ->
        %BudgetMonth{}
        |> BudgetMonth.changeset(%{
          budget_envelope_id: envelope.id,
          month: date.month,
          year: date.year,
          allocated_amount: amount
        })
        |> Repo.insert()

      existing ->
        existing
        |> BudgetMonth.changeset(%{allocated_amount: amount})
        |> Repo.update()
    end
  end

  defp assign_all_categories(envelope, category_ids) do
    Enum.each(category_ids, fn cat_id ->
      case assign_category(envelope, cat_id) do
        {:ok, _} -> :ok
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Assigns a category to a budget envelope.
  """
  def assign_category(%BudgetEnvelope{} = envelope, category_id) do
    %EnvelopeCategory{}
    |> EnvelopeCategory.changeset(%{budget_envelope_id: envelope.id, category_id: category_id})
    |> Repo.insert()
  end

  @doc """
  Removes a category assignment from an envelope.
  """
  def unassign_category(%BudgetEnvelope{} = envelope, category_id) do
    case Repo.get_by(EnvelopeCategory, budget_envelope_id: envelope.id, category_id: category_id) do
      nil -> {:ok, nil}
      ec -> Repo.delete(ec)
    end
  end

  @doc """
  Performs month rollover for all active envelopes:
  - fixed: copy same allocation amount
  - variable: copy previous month's allocated amount
  - rollover: carry unspent balance forward (capped if rollover_cap is set)

  Idempotent — skips envelopes that already have a budget_month for the target month.
  """
  def rollover_month(%Date{} = date) do
    prev = Date.shift(date, month: -1)

    active_envelopes =
      Repo.all(
        from e in BudgetEnvelope,
          where: is_nil(e.archived_at),
          preload: [envelope_categories: []]
      )

    Enum.each(active_envelopes, fn env ->
      unless Repo.get_by(BudgetMonth,
               budget_envelope_id: env.id,
               month: date.month,
               year: date.year
             ) do
        prev_bm =
          Repo.get_by(BudgetMonth, budget_envelope_id: env.id, month: prev.month, year: prev.year)

        rollover_envelope(env, prev_bm, prev, date)
      end
    end)

    :ok
  end

  defp rollover_envelope(_env, nil, _prev, _date), do: :ok

  defp rollover_envelope(
         %BudgetEnvelope{type: "fixed"} = env,
         %BudgetMonth{} = prev_bm,
         _prev,
         date
       ) do
    insert_budget_month(env.id, date, prev_bm.allocated_amount)
  end

  defp rollover_envelope(
         %BudgetEnvelope{type: "variable"} = env,
         %BudgetMonth{} = prev_bm,
         _prev,
         date
       ) do
    insert_budget_month(env.id, date, prev_bm.allocated_amount)
  end

  defp rollover_envelope(
         %BudgetEnvelope{type: "rollover"} = env,
         %BudgetMonth{} = prev_bm,
         prev,
         date
       ) do
    # Compute unspent = allocated - spent for previous month
    cat_ids = envelope_category_ids(env.id)
    prev_spent = spent_for_period(cat_ids, prev)
    unspent = Decimal.sub(prev_bm.allocated_amount, prev_spent)

    # Apply rollover cap if set
    carry =
      if env.rollover_cap && Decimal.compare(unspent, env.rollover_cap) == :gt do
        env.rollover_cap
      else
        unspent
      end

    amount = if Decimal.negative?(carry), do: Decimal.new("0"), else: carry
    insert_budget_month(env.id, date, amount)
  end

  defp rollover_envelope(_env, _prev_bm, _prev, _date), do: :ok

  defp insert_budget_month(envelope_id, date, amount) do
    Repo.insert!(%BudgetMonth{
      budget_envelope_id: envelope_id,
      month: date.month,
      year: date.year,
      allocated_amount: amount
    })
  end

  defp envelope_category_ids(envelope_id) do
    Repo.all(
      from ec in EnvelopeCategory,
        where: ec.budget_envelope_id == ^envelope_id,
        select: ec.category_id
    )
  end

  defp spent_for_period([], _date), do: Decimal.new("0")

  defp spent_for_period(cat_ids, date) do
    result =
      Repo.one(
        from t in Transaction,
          where:
            t.category_id in ^cat_ids and
              fragment("strftime('%Y', ?)", t.date) == ^Integer.to_string(date.year) and
              fragment("strftime('%m', ?)", t.date) == ^zero_padded(date.month),
          select: sum(t.amount)
      )

    raw = result || Decimal.new("0")
    if Decimal.negative?(raw), do: Decimal.negate(raw), else: raw
  end

  @doc """
  Returns transactions that belong to categories not mapped to any active envelope.
  """
  def list_unassigned_transactions(%Date{} = date) do
    assigned_cat_ids =
      Repo.all(
        from ec in EnvelopeCategory,
          join: env in BudgetEnvelope,
          on: ec.budget_envelope_id == env.id,
          where: is_nil(env.archived_at),
          select: ec.category_id
      )

    Repo.all(
      from t in Transaction,
        where:
          not is_nil(t.category_id) and
            t.category_id not in ^assigned_cat_ids and
            fragment("strftime('%Y', ?)", t.date) == ^Integer.to_string(date.year) and
            fragment("strftime('%m', ?)", t.date) == ^zero_padded(date.month),
        preload: [:category],
        order_by: [desc: t.date]
    )
  end

  defp zero_padded(n), do: String.pad_leading(Integer.to_string(n), 2, "0")
end
