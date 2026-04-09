defmodule Xactions.Portfolio.PortfolioTest do
  use Xactions.DataCase

  import Xactions.Fixtures

  alias Xactions.Portfolio
  alias Xactions.Sync.OFX

  setup do
    inst = institution!()
    account = account!(%{institution_id: inst.id, type: "brokerage"})
    {:ok, account: account}
  end

  describe "replace_holdings_for_account/2" do
    test "inserts holdings from brokerage OFX fixture", %{account: account} do
      ofx = File.read!("test/fixtures/ofx/brokerage_sample.ofx")
      {:ok, %{holding_data: holdings}} = OFX.parse(ofx)

      {:ok, count} = Portfolio.replace_holdings_for_account(account.id, holdings)
      assert count == 3

      all = Portfolio.list_holdings()
      symbols = Enum.map(all, & &1.symbol)
      assert "037833100" in symbols
      assert "594918104" in symbols
    end

    test "replaces existing holdings on second sync", %{account: account} do
      ofx = File.read!("test/fixtures/ofx/brokerage_sample.ofx")
      {:ok, %{holding_data: holdings}} = OFX.parse(ofx)

      {:ok, _} = Portfolio.replace_holdings_for_account(account.id, holdings)
      {:ok, count} = Portfolio.replace_holdings_for_account(account.id, holdings)
      assert count == 3

      assert length(Portfolio.list_holdings()) == 3
    end
  end

  describe "list_holdings/0" do
    test "computes current_value and gain_loss virtual fields", %{account: account} do
      holding!(%{
        account_id: account.id,
        symbol: "AAPL",
        quantity: Decimal.new("10"),
        cost_basis: Decimal.new("1500.00"),
        current_price: Decimal.new("185.40")
      })

      [h] = Portfolio.list_holdings()
      assert Decimal.equal?(h.current_value, Decimal.new("1854.00"))
      assert Decimal.equal?(h.unrealized_gain_loss, Decimal.new("354.00"))
    end

    test "handles nil cost_basis gracefully", %{account: account} do
      holding!(%{
        account_id: account.id,
        symbol: "MSFT",
        quantity: Decimal.new("5"),
        current_price: Decimal.new("420.75")
      })

      [h] = Portfolio.list_holdings()
      assert h.current_value != nil
      assert h.unrealized_gain_loss == nil
    end
  end

  describe "get_allocation/0" do
    test "groups holdings by asset class with percentages", %{account: account} do
      holding!(%{account_id: account.id, symbol: "AAPL", quantity: Decimal.new("10"),
                 current_price: Decimal.new("100.00"), asset_class: "equity"})
      holding!(%{account_id: account.id, symbol: "BND", quantity: Decimal.new("5"),
                 current_price: Decimal.new("100.00"), asset_class: "fixed_income"})

      allocation = Portfolio.get_allocation()
      equity = Enum.find(allocation, &(&1.class == "equity"))
      fi = Enum.find(allocation, &(&1.class == "fixed_income"))

      assert equity != nil
      assert fi != nil
      assert_in_delta equity.pct, 66.67, 0.1
      assert_in_delta fi.pct, 33.33, 0.1
    end
  end

  describe "oldest_price_timestamp/0" do
    test "returns oldest price_as_of across all holdings", %{account: account} do
      holding!(%{account_id: account.id, symbol: "AAPL",
                 quantity: Decimal.new("1"), current_price: Decimal.new("100"),
                 price_as_of: ~U[2026-04-09 09:00:00Z]})
      holding!(%{account_id: account.id, symbol: "MSFT",
                 quantity: Decimal.new("1"), current_price: Decimal.new("100"),
                 price_as_of: ~U[2026-04-08 09:00:00Z]})

      oldest = Portfolio.oldest_price_timestamp()
      assert oldest == ~U[2026-04-08 09:00:00Z]
    end

    test "returns nil when no holdings", do: assert(Portfolio.oldest_price_timestamp() == nil)
  end
end
