defmodule Xactions.Transactions.TransactionsTest do
  use Xactions.DataCase

  import Xactions.Fixtures

  alias Xactions.Transactions

  setup do
    inst = institution!(%{is_manual_only: true})
    account = account!(%{institution_id: inst.id, is_manual: true})
    cat = category!(%{name: "Food"})
    {:ok, account: account, category: cat}
  end

  describe "list_transactions/1" do
    test "returns all transactions for an account", %{account: account} do
      t1 = transaction!(%{account_id: account.id, merchant_name: "Grocery Store"})
      t2 = transaction!(%{account_id: account.id, merchant_name: "Coffee Shop"})

      results = Transactions.list_transactions(%{account_id: account.id})
      ids = Enum.map(results, & &1.id)
      assert t1.id in ids
      assert t2.id in ids
    end

    test "filters by category_id", %{account: account, category: cat} do
      t_cat = transaction!(%{account_id: account.id, category_id: cat.id})
      _t_no_cat = transaction!(%{account_id: account.id})

      results = Transactions.list_transactions(%{category_id: cat.id})
      assert length(results) == 1
      assert hd(results).id == t_cat.id
    end

    test "filters by date range", %{account: account} do
      old = transaction!(%{account_id: account.id, date: ~D[2024-01-15]})
      recent = transaction!(%{account_id: account.id, date: ~D[2025-06-01]})

      results = Transactions.list_transactions(%{date_from: ~D[2025-01-01], date_to: ~D[2025-12-31]})
      ids = Enum.map(results, & &1.id)
      assert recent.id in ids
      refute old.id in ids
    end

    test "filters by merchant query", %{account: account} do
      t = transaction!(%{account_id: account.id, merchant_name: "Whole Foods Market"})
      _other = transaction!(%{account_id: account.id, merchant_name: "Shell Gas"})

      results = Transactions.list_transactions(%{query: "whole foods"})
      assert length(results) == 1
      assert hd(results).id == t.id
    end

    test "paginates with limit and offset", %{account: account} do
      for _ <- 1..5, do: transaction!(%{account_id: account.id})

      page1 = Transactions.list_transactions(%{account_id: account.id, limit: 2, offset: 0})
      page2 = Transactions.list_transactions(%{account_id: account.id, limit: 2, offset: 2})

      assert length(page1) == 2
      assert length(page2) == 2
      refute Enum.any?(page1, fn t -> Enum.any?(page2, &(&1.id == t.id)) end)
    end
  end

  describe "update_category/2" do
    test "updates transaction category", %{account: account, category: cat} do
      txn = transaction!(%{account_id: account.id, merchant_name: "Starbucks"})
      {:ok, updated} = Transactions.update_category(txn, cat.id)
      assert updated.category_id == cat.id
    end

    test "upserts merchant rule on update", %{account: account, category: cat} do
      txn = transaction!(%{account_id: account.id, merchant_name: "Starbucks 123"})
      {:ok, _} = Transactions.update_category(txn, cat.id)

      rule = Xactions.Repo.get_by(Xactions.Transactions.MerchantRule, merchant_pattern: "starbucks")
      assert rule != nil
      assert rule.category_id == cat.id
    end

    test "updates existing merchant rule if pattern exists", %{account: account, category: cat} do
      cat2 = category!(%{name: "Coffee"})
      txn = transaction!(%{account_id: account.id, merchant_name: "Starbucks"})

      {:ok, _} = Transactions.update_category(txn, cat.id)
      {:ok, _} = Transactions.update_category(txn, cat2.id)

      rules = Xactions.Repo.all(Xactions.Transactions.MerchantRule)
      assert length(rules) == 1
      assert hd(rules).category_id == cat2.id
    end
  end

  describe "split_transaction/2" do
    test "splits transaction into two parts", %{account: account, category: cat} do
      cat2 = category!(%{name: "Health"})
      txn = transaction!(%{account_id: account.id, amount: Decimal.new("-50.00")})

      splits = [
        %{"category_id" => cat.id, "amount" => "-30.00"},
        %{"category_id" => cat2.id, "amount" => "-20.00"}
      ]

      {:ok, %{transaction: updated}} = Transactions.split_transaction(txn, splits)
      assert updated.is_split == true
      assert updated.category_id == nil
    end

    test "requires at least 2 splits", %{account: account, category: cat} do
      txn = transaction!(%{account_id: account.id, amount: Decimal.new("-50.00")})
      splits = [%{"category_id" => cat.id, "amount" => "-50.00"}]

      assert {:error, :min_splits} = Transactions.split_transaction(txn, splits)
    end

    test "rejects splits when amounts don't sum to parent amount", %{account: account, category: cat} do
      cat2 = category!(%{name: "Health"})
      txn = transaction!(%{account_id: account.id, amount: Decimal.new("-50.00")})

      splits = [
        %{"category_id" => cat.id, "amount" => "-30.00"},
        %{"category_id" => cat2.id, "amount" => "-15.00"}
      ]

      assert {:error, :amount_mismatch} = Transactions.split_transaction(txn, splits)
    end
  end

  describe "add_manual_transaction/1" do
    test "creates a manual transaction on a manual account", %{account: account, category: cat} do
      attrs = %{
        account_id: account.id,
        category_id: cat.id,
        date: Date.utc_today(),
        amount: Decimal.new("-25.00"),
        merchant_name: "Target",
        is_manual: true
      }

      {:ok, txn} = Transactions.add_manual_transaction(attrs)
      assert txn.merchant_name == "Target"
      assert txn.is_manual == true
    end

    test "rejects transaction on a non-manual account", %{category: cat} do
      inst = institution!()
      non_manual = account!(%{institution_id: inst.id, is_manual: false})

      attrs = %{
        account_id: non_manual.id,
        category_id: cat.id,
        date: Date.utc_today(),
        amount: Decimal.new("-25.00"),
        is_manual: true
      }

      assert {:error, :not_manual_account} = Transactions.add_manual_transaction(attrs)
    end
  end

  describe "apply_merchant_rules/1" do
    test "auto-categorizes transaction by merchant rule", %{account: account, category: cat} do
      Xactions.Repo.insert!(%Xactions.Transactions.MerchantRule{
        merchant_pattern: "amazon prime",
        category_id: cat.id
      })

      txn = transaction!(%{account_id: account.id, merchant_name: "Amazon Prime 99"})
      {:ok, updated} = Transactions.apply_merchant_rules(txn)
      assert updated.category_id == cat.id
    end

    test "no-ops when no matching rule", %{account: account} do
      txn = transaction!(%{account_id: account.id, merchant_name: "Unknown Store"})
      {:ok, updated} = Transactions.apply_merchant_rules(txn)
      assert updated.category_id == nil
    end
  end
end
