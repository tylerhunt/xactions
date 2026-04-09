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

  defp total_income(%Date{} = date) do
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

  defp total_allocated(%Date{} = date) do
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
      bm = Enum.find(env.budget_months, fn bm ->
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
  Creates a new budget envelope.
  """
  def create_envelope(attrs) do
    %BudgetEnvelope{}
    |> BudgetEnvelope.changeset(attrs)
    |> Repo.insert()
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
    case Repo.get_by(BudgetMonth, budget_envelope_id: envelope.id, month: date.month, year: date.year) do
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
      unless Repo.get_by(BudgetMonth, budget_envelope_id: env.id, month: date.month, year: date.year) do
        prev_bm = Repo.get_by(BudgetMonth, budget_envelope_id: env.id, month: prev.month, year: prev.year)
        rollover_envelope(env, prev_bm, prev, date)
      end
    end)

    :ok
  end

  defp rollover_envelope(_env, nil, _prev, _date), do: :ok

  defp rollover_envelope(%BudgetEnvelope{type: "fixed"} = env, %BudgetMonth{} = prev_bm, _prev, date) do
    insert_budget_month(env.id, date, prev_bm.allocated_amount)
  end

  defp rollover_envelope(%BudgetEnvelope{type: "variable"} = env, %BudgetMonth{} = prev_bm, _prev, date) do
    insert_budget_month(env.id, date, prev_bm.allocated_amount)
  end

  defp rollover_envelope(%BudgetEnvelope{type: "rollover"} = env, %BudgetMonth{} = prev_bm, prev, date) do
    # Compute unspent = allocated - spent for previous month
    cat_ids = envelope_category_ids(env.id)
    prev_spent = spent_for_period(cat_ids, prev)
    unspent = Decimal.sub(prev_bm.allocated_amount, prev_spent)

    # Apply rollover cap if set
    carry = if env.rollover_cap && Decimal.compare(unspent, env.rollover_cap) == :gt do
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
