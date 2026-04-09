defmodule Xactions.PerformanceTest do
  @moduledoc """
  Performance benchmarks asserting that critical paths meet latency requirements.

  These tests insert bulk data and measure query times. They are tagged `:performance`
  and excluded from the default test run. Run with:
    mix test --only performance
  """

  use Xactions.DataCase

  import Xactions.Fixtures

  alias Xactions.{Transactions, Reporting}

  @batch_size 500

  defp bulk_insert(table, rows) do
    rows
    |> Enum.chunk_every(@batch_size)
    |> Enum.each(&Xactions.Repo.insert_all(table, &1))
  end

  @tag :performance
  @tag timeout: 120_000
  test "transaction list query completes under 500ms with 50k rows" do
    inst = institution!()
    account = account!(%{institution_id: inst.id})
    cat = category!(%{name: "Food"})
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    today = Date.utc_today()

    transactions =
      for i <- 1..50_000 do
        %{
          account_id: account.id,
          category_id: cat.id,
          date: Date.add(today, -rem(i, 365)) |> Date.to_iso8601(),
          amount: "#{-1 * (rem(i, 100) + 1)}.00",
          merchant_name: "Store #{rem(i, 100)}",
          is_pending: 0,
          is_split: 0,
          is_manual: 0,
          inserted_at: now,
          updated_at: now
        }
      end

    bulk_insert("transactions", transactions)

    {elapsed_us, _result} =
      :timer.tc(fn ->
        Transactions.list_transactions(%{account_id: account.id, limit: 50})
      end)

    elapsed_ms = elapsed_us / 1_000
    assert elapsed_ms < 500,
           "Transaction list took #{Float.round(elapsed_ms, 1)}ms (limit: 500ms)"
  end

  @tag :performance
  @tag timeout: 120_000
  test "merchant search query completes under 500ms with 50k rows" do
    inst = institution!()
    account = account!(%{institution_id: inst.id})
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    today = Date.utc_today() |> Date.to_iso8601()

    transactions =
      for i <- 1..50_000 do
        %{
          account_id: account.id,
          date: today,
          amount: "-10.00",
          merchant_name: if(rem(i, 10) == 0, do: "Whole Foods #{i}", else: "Store #{i}"),
          is_pending: 0,
          is_split: 0,
          is_manual: 0,
          inserted_at: now,
          updated_at: now
        }
      end

    bulk_insert("transactions", transactions)

    {elapsed_us, _result} =
      :timer.tc(fn ->
        Transactions.list_transactions(%{query: "whole foods", limit: 50})
      end)

    elapsed_ms = elapsed_us / 1_000
    assert elapsed_ms < 500,
           "Merchant search took #{Float.round(elapsed_ms, 1)}ms (limit: 500ms)"
  end

  @tag :performance
  @tag timeout: 30_000
  test "net worth query completes under 2000ms" do
    inst = institution!()
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    accounts =
      for i <- 1..100 do
        %{
          institution_id: inst.id,
          name: "Account #{i}",
          type: if(rem(i, 5) == 0, do: "credit_card", else: "checking"),
          balance: "#{i * 1000}.00",
          currency: "USD",
          is_manual: false,
          is_active: true,
          inserted_at: now,
          updated_at: now
        }
      end

    Xactions.Repo.insert_all("accounts", accounts)

    {elapsed_us, _result} = :timer.tc(fn -> Reporting.net_worth() end)
    elapsed_ms = elapsed_us / 1_000
    assert elapsed_ms < 2_000,
           "Net worth query took #{Float.round(elapsed_ms, 1)}ms (limit: 2000ms)"
  end
end
