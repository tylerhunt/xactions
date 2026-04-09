defmodule Xactions.Budgeting.BudgetingTest do
  use Xactions.DataCase

  import Xactions.Fixtures

  alias Xactions.Budgeting
  alias Xactions.Repo

  @today Date.utc_today()
  @month @today.month
  @year @today.year

  setup do
    inst = institution!(%{is_manual_only: true})
    account = account!(%{institution_id: inst.id, is_manual: true})
    income_cat = category!(%{name: "Income"})
    food_cat = category!(%{name: "Food"})
    {:ok, account: account, income_cat: income_cat, food_cat: food_cat}
  end

  describe "to_be_budgeted/1" do
    test "equals income transactions minus allocations", %{account: account, income_cat: income_cat} do
      transaction!(%{account_id: account.id, category_id: income_cat.id,
                     amount: Decimal.new("2000.00"), date: @today})

      envelope = budget_envelope!(%{name: "Rent", type: "fixed"})
      budget_month!(%{budget_envelope_id: envelope.id, month: @month, year: @year,
                      allocated_amount: Decimal.new("500.00")})

      tbb = Budgeting.to_be_budgeted(@today)
      assert Decimal.equal?(tbb, Decimal.new("1500.00"))
    end

    test "returns zero when no income or allocations", do: assert(Decimal.equal?(Budgeting.to_be_budgeted(@today), Decimal.new("0")))

    test "TBB updates when income transaction is added", %{account: account, income_cat: income_cat} do
      before_tbb = Budgeting.to_be_budgeted(@today)

      transaction!(%{account_id: account.id, category_id: income_cat.id,
                     amount: Decimal.new("1000.00"), date: @today})

      after_tbb = Budgeting.to_be_budgeted(@today)
      assert Decimal.equal?(Decimal.sub(after_tbb, before_tbb), Decimal.new("1000.00"))
    end
  end

  describe "list_envelopes/1" do
    test "returns active envelopes with budgeted and spent amounts", %{account: account, food_cat: food_cat} do
      envelope = budget_envelope!(%{name: "Groceries", type: "variable"})
      budget_month!(%{budget_envelope_id: envelope.id, month: @month, year: @year,
                      allocated_amount: Decimal.new("400.00")})
      envelope_category!(%{budget_envelope_id: envelope.id, category_id: food_cat.id})
      transaction!(%{account_id: account.id, category_id: food_cat.id,
                     amount: Decimal.new("-150.00"), date: @today})

      [e] = Budgeting.list_envelopes(@today)
      assert e.name == "Groceries"
      assert Decimal.equal?(e.budgeted, Decimal.new("400.00"))
      assert Decimal.equal?(e.spent, Decimal.new("150.00"))
      assert Decimal.equal?(e.remaining, Decimal.new("250.00"))
    end

    test "excludes archived envelopes" do
      _archived = budget_envelope!(%{name: "Archived", type: "fixed",
                                      archived_at: DateTime.utc_now()})

      assert Budgeting.list_envelopes(@today) == []
    end
  end

  describe "create_envelope/1" do
    test "creates a valid envelope" do
      {:ok, env} = Budgeting.create_envelope(%{name: "Utilities", type: "fixed"})
      assert env.name == "Utilities"
    end
  end

  describe "archive_envelope/1" do
    test "marks envelope as archived" do
      env = budget_envelope!(%{name: "Old", type: "fixed"})
      {:ok, archived} = Budgeting.archive_envelope(env)
      assert archived.archived_at != nil
    end
  end

  describe "set_allocation/3" do
    test "creates budget_month for envelope" do
      env = budget_envelope!(%{name: "Rent", type: "fixed"})
      {:ok, bm} = Budgeting.set_allocation(env, @today, Decimal.new("1000.00"))
      assert Decimal.equal?(bm.allocated_amount, Decimal.new("1000.00"))
    end

    test "updates existing budget_month" do
      env = budget_envelope!(%{name: "Rent", type: "fixed"})
      {:ok, _} = Budgeting.set_allocation(env, @today, Decimal.new("1000.00"))
      {:ok, updated} = Budgeting.set_allocation(env, @today, Decimal.new("1200.00"))
      assert Decimal.equal?(updated.allocated_amount, Decimal.new("1200.00"))
    end
  end

  describe "assign_category/2" do
    test "assigns category to envelope", %{food_cat: food_cat} do
      env = budget_envelope!(%{name: "Food", type: "variable"})
      {:ok, ec} = Budgeting.assign_category(env, food_cat.id)
      assert ec.budget_envelope_id == env.id
      assert ec.category_id == food_cat.id
    end

    test "rejects double assignment to different envelopes", %{food_cat: food_cat} do
      env1 = budget_envelope!(%{name: "Food 1", type: "variable"})
      env2 = budget_envelope!(%{name: "Food 2", type: "variable"})
      {:ok, _} = Budgeting.assign_category(env1, food_cat.id)
      {:error, _} = Budgeting.assign_category(env2, food_cat.id)
    end
  end

  describe "rollover_month/1" do
    test "fixed envelope copies same allocation to new month" do
      env = budget_envelope!(%{name: "Rent", type: "fixed"})
      prev_month = Date.shift(@today, month: -1)
      budget_month!(%{budget_envelope_id: env.id, month: prev_month.month,
                      year: prev_month.year, allocated_amount: Decimal.new("1000.00")})

      Budgeting.rollover_month(@today)

      bm = Repo.get_by!(Xactions.Budgeting.BudgetMonth,
        budget_envelope_id: env.id, month: @month, year: @year)
      assert Decimal.equal?(bm.allocated_amount, Decimal.new("1000.00"))
    end

    test "variable envelope pre-fills with previous month amount" do
      env = budget_envelope!(%{name: "Groceries", type: "variable"})
      prev_month = Date.shift(@today, month: -1)
      budget_month!(%{budget_envelope_id: env.id, month: prev_month.month,
                      year: prev_month.year, allocated_amount: Decimal.new("400.00")})

      Budgeting.rollover_month(@today)

      bm = Repo.get_by!(Xactions.Budgeting.BudgetMonth,
        budget_envelope_id: env.id, month: @month, year: @year)
      assert Decimal.equal?(bm.allocated_amount, Decimal.new("400.00"))
    end

    test "rollover envelope accumulates unspent balance", %{account: account, food_cat: food_cat} do
      env = budget_envelope!(%{name: "Savings", type: "rollover"})
      envelope_category!(%{budget_envelope_id: env.id, category_id: food_cat.id})
      prev_month = Date.shift(@today, month: -1)
      budget_month!(%{budget_envelope_id: env.id, month: prev_month.month,
                      year: prev_month.year, allocated_amount: Decimal.new("500.00")})
      # Spend $200 in the previous month
      transaction!(%{account_id: account.id, category_id: food_cat.id,
                     amount: Decimal.new("-200.00"), date: prev_month})

      Budgeting.rollover_month(@today)

      bm = Repo.get_by!(Xactions.Budgeting.BudgetMonth,
        budget_envelope_id: env.id, month: @month, year: @year)
      # $300 unspent carries forward
      assert Decimal.equal?(bm.allocated_amount, Decimal.new("300.00"))
    end

    test "rollover cap limits carry-forward surplus", %{account: account, food_cat: food_cat} do
      env = budget_envelope!(%{name: "Vacation", type: "rollover", rollover_cap: Decimal.new("100.00")})
      envelope_category!(%{budget_envelope_id: env.id, category_id: food_cat.id})
      prev_month = Date.shift(@today, month: -1)
      budget_month!(%{budget_envelope_id: env.id, month: prev_month.month,
                      year: prev_month.year, allocated_amount: Decimal.new("500.00")})
      # Spend nothing — $500 unspent, cap is $100

      Budgeting.rollover_month(@today)

      bm = Repo.get_by!(Xactions.Budgeting.BudgetMonth,
        budget_envelope_id: env.id, month: @month, year: @year)
      assert Decimal.equal?(bm.allocated_amount, Decimal.new("100.00"))
    end

    test "archived envelope excluded from rollover" do
      env = budget_envelope!(%{name: "Old", type: "fixed", archived_at: DateTime.utc_now()})
      prev_month = Date.shift(@today, month: -1)
      budget_month!(%{budget_envelope_id: env.id, month: prev_month.month,
                      year: prev_month.year, allocated_amount: Decimal.new("300.00")})

      Budgeting.rollover_month(@today)

      assert nil == Repo.get_by(Xactions.Budgeting.BudgetMonth,
        budget_envelope_id: env.id, month: @month, year: @year)
    end

    test "idempotent: does not create duplicate budget_months" do
      env = budget_envelope!(%{name: "Rent", type: "fixed"})
      prev_month = Date.shift(@today, month: -1)
      budget_month!(%{budget_envelope_id: env.id, month: prev_month.month,
                      year: prev_month.year, allocated_amount: Decimal.new("1000.00")})

      Budgeting.rollover_month(@today)
      Budgeting.rollover_month(@today)

      count = Repo.aggregate(
        from(b in Xactions.Budgeting.BudgetMonth,
          where: b.budget_envelope_id == ^env.id and b.month == ^@month and b.year == ^@year),
        :count
      )
      assert count == 1
    end
  end

  describe "list_unassigned_transactions/1" do
    test "returns transactions in categories not mapped to any active envelope",
         %{account: account, food_cat: food_cat} do
      other_cat = category!(%{name: "Shopping"})
      t_unassigned = transaction!(%{account_id: account.id, category_id: other_cat.id, date: @today})
      t_assigned = transaction!(%{account_id: account.id, category_id: food_cat.id, date: @today})

      env = budget_envelope!(%{name: "Food", type: "variable"})
      envelope_category!(%{budget_envelope_id: env.id, category_id: food_cat.id})

      unassigned = Budgeting.list_unassigned_transactions(@today)
      ids = Enum.map(unassigned, & &1.id)
      assert t_unassigned.id in ids
      refute t_assigned.id in ids
    end
  end
end
