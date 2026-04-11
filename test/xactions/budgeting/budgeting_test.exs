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
    test "equals income transactions minus allocations", %{
      account: account,
      income_cat: income_cat
    } do
      transaction!(%{
        account_id: account.id,
        category_id: income_cat.id,
        amount: Decimal.new("2000.00"),
        date: @today
      })

      envelope = budget_envelope!(%{name: "Rent", type: "fixed"})

      budget_month!(%{
        budget_envelope_id: envelope.id,
        month: @month,
        year: @year,
        allocated_amount: Decimal.new("500.00")
      })

      tbb = Budgeting.to_be_budgeted(@today)
      assert Decimal.equal?(tbb, Decimal.new("1500.00"))
    end

    test "returns zero when no income or allocations",
      do: assert(Decimal.equal?(Budgeting.to_be_budgeted(@today), Decimal.new("0")))

    test "TBB updates when income transaction is added", %{
      account: account,
      income_cat: income_cat
    } do
      before_tbb = Budgeting.to_be_budgeted(@today)

      transaction!(%{
        account_id: account.id,
        category_id: income_cat.id,
        amount: Decimal.new("1000.00"),
        date: @today
      })

      after_tbb = Budgeting.to_be_budgeted(@today)
      assert Decimal.equal?(Decimal.sub(after_tbb, before_tbb), Decimal.new("1000.00"))
    end
  end

  describe "list_envelopes/1" do
    test "returns active envelopes with budgeted and spent amounts", %{
      account: account,
      food_cat: food_cat
    } do
      envelope = budget_envelope!(%{name: "Groceries", type: "variable"})

      budget_month!(%{
        budget_envelope_id: envelope.id,
        month: @month,
        year: @year,
        allocated_amount: Decimal.new("400.00")
      })

      envelope_category!(%{budget_envelope_id: envelope.id, category_id: food_cat.id})

      transaction!(%{
        account_id: account.id,
        category_id: food_cat.id,
        amount: Decimal.new("-150.00"),
        date: @today
      })

      [e] = Budgeting.list_envelopes(@today)
      assert e.name == "Groceries"
      assert Decimal.equal?(e.budgeted, Decimal.new("400.00"))
      assert Decimal.equal?(e.spent, Decimal.new("150.00"))
      assert Decimal.equal?(e.remaining, Decimal.new("250.00"))
    end

    test "excludes archived envelopes" do
      _archived =
        budget_envelope!(%{name: "Archived", type: "fixed", archived_at: DateTime.utc_now()})

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

      budget_month!(%{
        budget_envelope_id: env.id,
        month: prev_month.month,
        year: prev_month.year,
        allocated_amount: Decimal.new("1000.00")
      })

      Budgeting.rollover_month(@today)

      bm =
        Repo.get_by!(Xactions.Budgeting.BudgetMonth,
          budget_envelope_id: env.id,
          month: @month,
          year: @year
        )

      assert Decimal.equal?(bm.allocated_amount, Decimal.new("1000.00"))
    end

    test "variable envelope pre-fills with previous month amount" do
      env = budget_envelope!(%{name: "Groceries", type: "variable"})
      prev_month = Date.shift(@today, month: -1)

      budget_month!(%{
        budget_envelope_id: env.id,
        month: prev_month.month,
        year: prev_month.year,
        allocated_amount: Decimal.new("400.00")
      })

      Budgeting.rollover_month(@today)

      bm =
        Repo.get_by!(Xactions.Budgeting.BudgetMonth,
          budget_envelope_id: env.id,
          month: @month,
          year: @year
        )

      assert Decimal.equal?(bm.allocated_amount, Decimal.new("400.00"))
    end

    test "rollover envelope accumulates unspent balance", %{account: account, food_cat: food_cat} do
      env = budget_envelope!(%{name: "Savings", type: "rollover"})
      envelope_category!(%{budget_envelope_id: env.id, category_id: food_cat.id})
      prev_month = Date.shift(@today, month: -1)

      budget_month!(%{
        budget_envelope_id: env.id,
        month: prev_month.month,
        year: prev_month.year,
        allocated_amount: Decimal.new("500.00")
      })

      # Spend $200 in the previous month
      transaction!(%{
        account_id: account.id,
        category_id: food_cat.id,
        amount: Decimal.new("-200.00"),
        date: prev_month
      })

      Budgeting.rollover_month(@today)

      bm =
        Repo.get_by!(Xactions.Budgeting.BudgetMonth,
          budget_envelope_id: env.id,
          month: @month,
          year: @year
        )

      # $300 unspent carries forward
      assert Decimal.equal?(bm.allocated_amount, Decimal.new("300.00"))
    end

    test "rollover cap limits carry-forward surplus", %{food_cat: food_cat} do
      env =
        budget_envelope!(%{
          name: "Vacation",
          type: "rollover",
          rollover_cap: Decimal.new("100.00")
        })

      envelope_category!(%{budget_envelope_id: env.id, category_id: food_cat.id})
      prev_month = Date.shift(@today, month: -1)

      budget_month!(%{
        budget_envelope_id: env.id,
        month: prev_month.month,
        year: prev_month.year,
        allocated_amount: Decimal.new("500.00")
      })

      # Spend nothing — $500 unspent, cap is $100

      Budgeting.rollover_month(@today)

      bm =
        Repo.get_by!(Xactions.Budgeting.BudgetMonth,
          budget_envelope_id: env.id,
          month: @month,
          year: @year
        )

      assert Decimal.equal?(bm.allocated_amount, Decimal.new("100.00"))
    end

    test "archived envelope excluded from rollover" do
      env = budget_envelope!(%{name: "Old", type: "fixed", archived_at: DateTime.utc_now()})
      prev_month = Date.shift(@today, month: -1)

      budget_month!(%{
        budget_envelope_id: env.id,
        month: prev_month.month,
        year: prev_month.year,
        allocated_amount: Decimal.new("300.00")
      })

      Budgeting.rollover_month(@today)

      assert nil ==
               Repo.get_by(Xactions.Budgeting.BudgetMonth,
                 budget_envelope_id: env.id,
                 month: @month,
                 year: @year
               )
    end

    test "idempotent: does not create duplicate budget_months" do
      env = budget_envelope!(%{name: "Rent", type: "fixed"})
      prev_month = Date.shift(@today, month: -1)

      budget_month!(%{
        budget_envelope_id: env.id,
        month: prev_month.month,
        year: prev_month.year,
        allocated_amount: Decimal.new("1000.00")
      })

      Budgeting.rollover_month(@today)
      Budgeting.rollover_month(@today)

      count =
        Repo.aggregate(
          from(b in Xactions.Budgeting.BudgetMonth,
            where: b.budget_envelope_id == ^env.id and b.month == ^@month and b.year == ^@year
          ),
          :count
        )

      assert count == 1
    end
  end

  describe "total_income/1" do
    test "returns sum of income-category transactions for the month",
         %{account: account, income_cat: income_cat} do
      transaction!(%{
        account_id: account.id,
        category_id: income_cat.id,
        amount: Decimal.new("3000.00"),
        date: @today
      })

      transaction!(%{
        account_id: account.id,
        category_id: income_cat.id,
        amount: Decimal.new("500.00"),
        date: @today
      })

      assert Decimal.equal?(Budgeting.total_income(@today), Decimal.new("3500.00"))
    end

    test "returns zero when no income transactions" do
      assert Decimal.equal?(Budgeting.total_income(@today), Decimal.new("0"))
    end

    test "excludes income from other months", %{account: account, income_cat: income_cat} do
      other_month = Date.shift(@today, month: -1)

      transaction!(%{
        account_id: account.id,
        category_id: income_cat.id,
        amount: Decimal.new("2000.00"),
        date: other_month
      })

      assert Decimal.equal?(Budgeting.total_income(@today), Decimal.new("0"))
    end
  end

  describe "total_allocated/1" do
    test "returns sum of allocations for the month" do
      env1 = budget_envelope!(%{name: "Rent", type: "fixed"})
      env2 = budget_envelope!(%{name: "Food", type: "variable"})

      budget_month!(%{
        budget_envelope_id: env1.id,
        month: @month,
        year: @year,
        allocated_amount: Decimal.new("1200.00")
      })

      budget_month!(%{
        budget_envelope_id: env2.id,
        month: @month,
        year: @year,
        allocated_amount: Decimal.new("400.00")
      })

      assert Decimal.equal?(Budgeting.total_allocated(@today), Decimal.new("1600.00"))
    end

    test "returns zero when no allocations" do
      assert Decimal.equal?(Budgeting.total_allocated(@today), Decimal.new("0"))
    end

    test "excludes archived envelope allocations" do
      env = budget_envelope!(%{name: "Old", type: "fixed", archived_at: DateTime.utc_now()})

      budget_month!(%{
        budget_envelope_id: env.id,
        month: @month,
        year: @year,
        allocated_amount: Decimal.new("500.00")
      })

      assert Decimal.equal?(Budgeting.total_allocated(@today), Decimal.new("0"))
    end
  end

  describe "total_spent/1" do
    test "returns sum of spending across all active envelopes for the month",
         %{account: account, food_cat: food_cat} do
      env = budget_envelope!(%{name: "Groceries", type: "variable"})
      envelope_category!(%{budget_envelope_id: env.id, category_id: food_cat.id})

      transaction!(%{
        account_id: account.id,
        category_id: food_cat.id,
        amount: Decimal.new("-150.00"),
        date: @today
      })

      transaction!(%{
        account_id: account.id,
        category_id: food_cat.id,
        amount: Decimal.new("-80.00"),
        date: @today
      })

      assert Decimal.equal?(Budgeting.total_spent(@today), Decimal.new("230.00"))
    end

    test "returns zero when no spending" do
      assert Decimal.equal?(Budgeting.total_spent(@today), Decimal.new("0"))
    end

    test "excludes spending from other months", %{account: account, food_cat: food_cat} do
      env = budget_envelope!(%{name: "Groceries", type: "variable"})
      envelope_category!(%{budget_envelope_id: env.id, category_id: food_cat.id})
      other_month = Date.shift(@today, month: -1)

      transaction!(%{
        account_id: account.id,
        category_id: food_cat.id,
        amount: Decimal.new("-100.00"),
        date: other_month
      })

      assert Decimal.equal?(Budgeting.total_spent(@today), Decimal.new("0"))
    end
  end

  describe "create_envelope_with_categories/2" do
    test "creates envelope and assigns categories", %{food_cat: food_cat, income_cat: income_cat} do
      {:ok, env} =
        Budgeting.create_envelope_with_categories(
          %{name: "Groceries", type: "variable"},
          [food_cat.id, income_cat.id]
        )

      assert env.name == "Groceries"

      cat_ids =
        Repo.all(
          from ec in Xactions.Budgeting.EnvelopeCategory,
            where: ec.budget_envelope_id == ^env.id,
            select: ec.category_id
        )

      assert food_cat.id in cat_ids
      assert income_cat.id in cat_ids
    end

    test "returns error for empty category list" do
      {:error, reason} =
        Budgeting.create_envelope_with_categories(%{name: "Empty", type: "fixed"}, [])

      assert reason == :no_categories
    end

    test "rolls back envelope if category assignment fails", %{food_cat: food_cat} do
      env1 = budget_envelope!(%{name: "Taken", type: "variable"})
      envelope_category!(%{budget_envelope_id: env1.id, category_id: food_cat.id})

      {:error, _} =
        Budgeting.create_envelope_with_categories(
          %{name: "Conflict", type: "variable"},
          [food_cat.id]
        )

      refute Repo.get_by(Xactions.Budgeting.BudgetEnvelope, name: "Conflict")
    end

    test "returns changeset error for invalid envelope attrs" do
      {:error, changeset} =
        Budgeting.create_envelope_with_categories(%{name: "", type: "fixed"}, [1])

      assert changeset.errors[:name]
    end
  end

  describe "update_envelope/3" do
    test "updates envelope name and type", %{food_cat: food_cat} do
      env = budget_envelope!(%{name: "Old Name", type: "fixed"})
      envelope_category!(%{budget_envelope_id: env.id, category_id: food_cat.id})

      {:ok, updated} =
        Budgeting.update_envelope(env, %{name: "New Name", type: "variable"}, [food_cat.id])

      assert updated.name == "New Name"
      assert updated.type == "variable"
    end

    test "atomically replaces category assignments", %{food_cat: food_cat, income_cat: income_cat} do
      env = budget_envelope!(%{name: "Food", type: "variable"})
      envelope_category!(%{budget_envelope_id: env.id, category_id: food_cat.id})

      {:ok, _} =
        Budgeting.update_envelope(env, %{name: "Food", type: "variable"}, [income_cat.id])

      cat_ids =
        Repo.all(
          from ec in Xactions.Budgeting.EnvelopeCategory,
            where: ec.budget_envelope_id == ^env.id,
            select: ec.category_id
        )

      refute food_cat.id in cat_ids
      assert income_cat.id in cat_ids
    end

    test "allows empty category_ids (validation is caller's responsibility)", %{
      food_cat: food_cat
    } do
      env = budget_envelope!(%{name: "Food", type: "variable"})
      envelope_category!(%{budget_envelope_id: env.id, category_id: food_cat.id})

      {:ok, _} = Budgeting.update_envelope(env, %{name: "Food", type: "variable"}, [])

      cat_ids =
        Repo.all(
          from ec in Xactions.Budgeting.EnvelopeCategory,
            where: ec.budget_envelope_id == ^env.id,
            select: ec.category_id
        )

      assert cat_ids == []
    end

    test "returns changeset error for invalid attrs", %{food_cat: food_cat} do
      env = budget_envelope!(%{name: "Food", type: "variable"})
      envelope_category!(%{budget_envelope_id: env.id, category_id: food_cat.id})

      {:error, changeset} =
        Budgeting.update_envelope(env, %{name: "", type: "variable"}, [food_cat.id])

      assert changeset.errors[:name]
    end

    test "rolls back if category conflict occurs", %{food_cat: food_cat} do
      env1 = budget_envelope!(%{name: "Food 1", type: "variable"})
      env2 = budget_envelope!(%{name: "Food 2", type: "variable"})
      envelope_category!(%{budget_envelope_id: env2.id, category_id: food_cat.id})

      {:error, _} =
        Budgeting.update_envelope(env1, %{name: "Food 1", type: "variable"}, [food_cat.id])

      # env1 name should be unchanged
      assert Repo.get!(Xactions.Budgeting.BudgetEnvelope, env1.id).name == "Food 1"
    end
  end

  describe "create_envelope/1 color" do
    test "auto-assigns a palette color when none provided" do
      {:ok, env} = Budgeting.create_envelope(%{name: "New Env", type: "fixed"})
      assert env.color =~ ~r/^#[0-9a-fA-F]{6}$/
    end

    test "uses provided color when valid hex" do
      {:ok, env} = Budgeting.create_envelope(%{name: "Green", type: "fixed", color: "#10b981"})
      assert env.color == "#10b981"
    end

    test "rejects invalid hex color" do
      {:error, changeset} =
        Budgeting.create_envelope(%{name: "Bad", type: "fixed", color: "notacolor"})

      assert changeset.errors[:color]
    end

    test "cycles through palette for multiple envelopes" do
      colors =
        for i <- 1..9 do
          {:ok, env} = Budgeting.create_envelope(%{name: "Env #{i}", type: "fixed"})
          env.color
        end

      # All colors must be valid hex
      assert Enum.all?(colors, &(&1 =~ ~r/^#[0-9a-fA-F]{6}$/))
    end
  end

  describe "list_available_categories/1" do
    test "returns all categories when no envelopes exist", %{
      food_cat: food_cat,
      income_cat: income_cat
    } do
      cats = Budgeting.list_available_categories()
      ids = Enum.map(cats, & &1.id)
      assert food_cat.id in ids
      assert income_cat.id in ids
    end

    test "excludes categories assigned to active envelopes", %{food_cat: food_cat} do
      env = budget_envelope!(%{name: "Food", type: "variable"})
      envelope_category!(%{budget_envelope_id: env.id, category_id: food_cat.id})

      cats = Budgeting.list_available_categories()
      ids = Enum.map(cats, & &1.id)
      refute food_cat.id in ids
    end

    test "includes categories assigned to archived envelopes", %{food_cat: food_cat} do
      env = budget_envelope!(%{name: "Old", type: "fixed", archived_at: DateTime.utc_now()})
      envelope_category!(%{budget_envelope_id: env.id, category_id: food_cat.id})

      cats = Budgeting.list_available_categories()
      ids = Enum.map(cats, & &1.id)
      assert food_cat.id in ids
    end

    test "with except_envelope_id includes that envelope's own categories", %{food_cat: food_cat} do
      env = budget_envelope!(%{name: "Food", type: "variable"})
      envelope_category!(%{budget_envelope_id: env.id, category_id: food_cat.id})

      cats = Budgeting.list_available_categories(except_envelope_id: env.id)
      ids = Enum.map(cats, & &1.id)
      assert food_cat.id in ids
    end

    test "with except_envelope_id still excludes categories on other envelopes", %{
      food_cat: food_cat
    } do
      other_cat = category!(%{name: "Shopping"})
      env1 = budget_envelope!(%{name: "Food", type: "variable"})
      env2 = budget_envelope!(%{name: "Shopping", type: "variable"})
      envelope_category!(%{budget_envelope_id: env1.id, category_id: food_cat.id})
      envelope_category!(%{budget_envelope_id: env2.id, category_id: other_cat.id})

      cats = Budgeting.list_available_categories(except_envelope_id: env1.id)
      ids = Enum.map(cats, & &1.id)
      assert food_cat.id in ids
      refute other_cat.id in ids
    end
  end

  describe "list_unassigned_transactions/1" do
    test "returns transactions in categories not mapped to any active envelope",
         %{account: account, food_cat: food_cat} do
      other_cat = category!(%{name: "Shopping"})

      t_unassigned =
        transaction!(%{account_id: account.id, category_id: other_cat.id, date: @today})

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
