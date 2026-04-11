defmodule Xactions.Reporting do
  @moduledoc """
  Context for financial reports: net worth, spending by envelope, and month-over-month comparisons.
  """

  import Ecto.Query

  alias Xactions.Repo
  alias Xactions.Accounts.Account
  alias Xactions.Transactions.Transaction
  alias Xactions.Budgeting.{BudgetEnvelope, EnvelopeCategory}

  @asset_types ~w(checking savings brokerage investment cash)
  @liability_types ~w(credit_card loan mortgage)

  @doc "Net worth = total assets - total liabilities."
  def net_worth do
    assets = sum_balances(@asset_types)
    liabilities = sum_balances(@liability_types)
    Decimal.sub(assets, Decimal.abs(liabilities))
  end

  defp sum_balances(types) do
    result =
      Repo.one(
        from a in Account,
          where: a.type in ^types and a.is_active == true,
          select: sum(a.balance)
      )

    result || Decimal.new("0")
  end

  @doc """
  Returns spending per envelope for a given month/year.
  Each entry: `%{envelope_name: string, spent: Decimal}`
  """
  def spending_by_envelope(month, year) do
    active_envelopes =
      Repo.all(
        from e in BudgetEnvelope,
          where: is_nil(e.archived_at),
          preload: [envelope_categories: []]
      )

    Enum.map(active_envelopes, fn env ->
      cat_ids = Enum.map(env.envelope_categories, & &1.category_id)
      spent = envelope_spent(cat_ids, month, year)
      %{envelope_name: env.name, envelope_id: env.id, spent: spent}
    end)
  end

  defp envelope_spent([], _month, _year), do: Decimal.new("0")

  defp envelope_spent(cat_ids, month, year) do
    result =
      Repo.one(
        from t in Transaction,
          where:
            t.category_id in ^cat_ids and
              fragment("strftime('%m', ?)", t.date) == ^zero_padded(month) and
              fragment("strftime('%Y', ?)", t.date) == ^Integer.to_string(year),
          select: sum(t.amount)
      )

    raw = result || Decimal.new("0")
    if Decimal.negative?(raw), do: Decimal.negate(raw), else: raw
  end

  @doc """
  Compares spending between the given month and the previous month by envelope.
  Returns list of `%{envelope_name, current, previous, delta, pct}`.
  """
  def month_over_month(month, year) do
    prev_date = Date.shift(Date.new!(year, month, 1), month: -1)
    current = spending_by_envelope(month, year)
    previous = spending_by_envelope(prev_date.month, prev_date.year)

    Enum.map(current, fn curr ->
      prev = Enum.find(previous, %{spent: Decimal.new("0")}, &(&1.envelope_name == curr.envelope_name))
      delta = Decimal.sub(curr.spent, prev.spent)

      pct =
        if Decimal.equal?(prev.spent, Decimal.new("0")) do
          nil
        else
          delta
          |> Decimal.div(prev.spent)
          |> Decimal.mult(Decimal.new("100"))
          |> Decimal.to_float()
        end

      %{
        envelope_name: curr.envelope_name,
        current: curr.spent,
        previous: prev.spent,
        delta: delta,
        pct: pct
      }
    end)
  end

  @doc """
  Returns trailing N months of net worth snapshots.
  Since we don't store historical balances, this returns the current net worth
  for each month. Returns `[%{month: Date, net_worth: Decimal}]`.
  """
  def net_worth_history(trailing_months) do
    current = net_worth()
    today = Date.utc_today()

    for i <- 0..(trailing_months - 1) do
      month_date = Date.shift(today, month: -i) |> Date.beginning_of_month()
      %{month: month_date, net_worth: current}
    end
    |> Enum.reverse()
  end

  @doc """
  Returns a (month × envelope) matrix of allocated and spent amounts.
  Trailing 12 months.
  """
  def budget_history_grid do
    envelopes =
      Repo.all(
        from e in BudgetEnvelope,
          where: is_nil(e.archived_at),
          preload: [
            budget_months: [],
            envelope_categories: []
          ],
          order_by: [asc: e.name]
      )

    today = Date.utc_today()
    months = for i <- 0..11, do: Date.shift(today, month: -i)

    %{
      envelopes: Enum.map(envelopes, & &1.name),
      months: Enum.map(months, &Date.beginning_of_month/1),
      data:
        Enum.map(envelopes, fn env ->
          Enum.map(months, fn m ->
            bm = Enum.find(env.budget_months, fn b -> b.month == m.month && b.year == m.year end)
            cat_ids = Enum.map(env.envelope_categories, & &1.category_id)
            spent = spent_for_month(cat_ids, m.month, m.year)

            %{
              allocated: (bm && bm.allocated_amount) || Decimal.new("0"),
              spent: spent
            }
          end)
        end)
    }
  end

  defp spent_for_month([], _month, _year), do: Decimal.new("0")

  defp spent_for_month(cat_ids, month, year) do
    result =
      Repo.one(
        from t in Transaction,
          where:
            t.category_id in ^cat_ids and
              fragment("strftime('%m', ?)", t.date) == ^zero_padded(month) and
              fragment("strftime('%Y', ?)", t.date) == ^Integer.to_string(year),
          select: sum(t.amount)
      )

    raw = result || Decimal.new("0")
    if Decimal.negative?(raw), do: Decimal.negate(raw), else: raw
  end

  defp zero_padded(n), do: String.pad_leading(Integer.to_string(n), 2, "0")
end
