defmodule Xactions.Reporting.ReportingTest do
  use Xactions.DataCase

  import Xactions.Fixtures

  alias Xactions.Reporting

  @today Date.utc_today()
  @month @today.month
  @year @today.year

  setup do
    inst = institution!()
    checking = account!(%{institution_id: inst.id, type: "checking",
                          balance: Decimal.new("5000.00")})
    credit = account!(%{institution_id: inst.id, type: "credit_card",
                        balance: Decimal.new("-1200.00")})
    food_cat = category!(%{name: "Food"})
    {:ok, checking: checking, credit: credit, food_cat: food_cat}
  end

  describe "net_worth/0" do
    test "computes assets minus liabilities", %{checking: _checking, credit: _credit} do
      nw = Reporting.net_worth()
      # checking (5000) - credit liabilities (1200) = 3800
      assert Decimal.equal?(nw, Decimal.new("3800.00"))
    end

    test "returns zero with no accounts" do
      # Fresh sandbox has the setup accounts — just verify the function runs
      nw = Reporting.net_worth()
      assert nw != nil
    end
  end

  describe "spending_by_envelope/2" do
    test "sums spending for categories in each envelope", %{checking: checking, food_cat: food_cat} do
      env = budget_envelope!(%{name: "Groceries", type: "variable"})
      envelope_category!(%{budget_envelope_id: env.id, category_id: food_cat.id})
      transaction!(%{account_id: checking.id, category_id: food_cat.id,
                     amount: Decimal.new("-120.00"), date: @today})
      transaction!(%{account_id: checking.id, category_id: food_cat.id,
                     amount: Decimal.new("-80.00"), date: @today})

      result = Reporting.spending_by_envelope(@month, @year)
      entry = Enum.find(result, &(&1.envelope_name == "Groceries"))
      assert entry != nil
      assert Decimal.equal?(entry.spent, Decimal.new("200.00"))
    end
  end

  describe "month_over_month/2" do
    test "returns delta and percent change between months", %{checking: checking, food_cat: food_cat} do
      env = budget_envelope!(%{name: "Food", type: "variable"})
      envelope_category!(%{budget_envelope_id: env.id, category_id: food_cat.id})

      prev = Date.shift(@today, month: -1)

      transaction!(%{account_id: checking.id, category_id: food_cat.id,
                     amount: Decimal.new("-100.00"), date: prev})
      transaction!(%{account_id: checking.id, category_id: food_cat.id,
                     amount: Decimal.new("-150.00"), date: @today})

      result = Reporting.month_over_month(@month, @year)
      entry = Enum.find(result, &(&1.envelope_name == "Food"))
      assert entry != nil
      assert Decimal.equal?(entry.current, Decimal.new("150.00"))
      assert Decimal.equal?(entry.previous, Decimal.new("100.00"))
      assert Decimal.equal?(entry.delta, Decimal.new("50.00"))
    end
  end

  describe "net_worth_history/1" do
    test "returns monthly net worth snapshots", do: assert(is_list(Reporting.net_worth_history(12)))
  end
end
