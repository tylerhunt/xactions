defmodule Xactions.Sync.OFXTest do
  use ExUnit.Case, async: true

  alias Xactions.Sync.OFX

  @checking_ofx File.read!("test/fixtures/ofx/checking_sample.ofx")
  @credit_card_ofx File.read!("test/fixtures/ofx/credit_card_sample.ofx")
  @brokerage_ofx File.read!("test/fixtures/ofx/brokerage_sample.ofx")

  describe "parse/1 — checking account" do
    test "returns ok tuple" do
      assert {:ok, _result} = OFX.parse(@checking_ofx)
    end

    test "extracts account data" do
      {:ok, result} = OFX.parse(@checking_ofx)
      assert result.account_data.type == "checking"
      assert result.account_data.external_account_id == "000111222333"
      assert Decimal.equal?(result.account_data.balance, Decimal.new("4823.17"))
    end

    test "extracts 4 transactions" do
      {:ok, result} = OFX.parse(@checking_ofx)
      assert length(result.transaction_data) == 4
    end

    test "parses debit transaction correctly" do
      {:ok, result} = OFX.parse(@checking_ofx)
      txn = Enum.find(result.transaction_data, &(&1.fit_id == "20260403001"))
      assert txn.merchant_name == "WHOLE FOODS MARKET"
      assert Decimal.equal?(txn.amount, Decimal.new("-52.34"))
      assert txn.date == ~D[2026-04-03]
      assert txn.is_pending == false
    end

    test "parses credit transaction correctly" do
      {:ok, result} = OFX.parse(@checking_ofx)
      txn = Enum.find(result.transaction_data, &(&1.fit_id == "20260401001"))
      assert Decimal.positive?(txn.amount)
    end

    test "returns empty holdings for checking" do
      {:ok, result} = OFX.parse(@checking_ofx)
      assert result.holding_data == []
    end
  end

  describe "parse/1 — credit card" do
    test "extracts account data with negative balance" do
      {:ok, result} = OFX.parse(@credit_card_ofx)
      assert result.account_data.type == "credit_card"
      assert Decimal.negative?(result.account_data.balance)
    end

    test "extracts 4 transactions" do
      {:ok, result} = OFX.parse(@credit_card_ofx)
      assert length(result.transaction_data) == 4
    end

    test "preserves FITIDs" do
      {:ok, result} = OFX.parse(@credit_card_ofx)
      fit_ids = Enum.map(result.transaction_data, & &1.fit_id)
      assert "CC20260405001" in fit_ids
    end
  end

  describe "parse/1 — brokerage" do
    test "extracts 3 holdings" do
      {:ok, result} = OFX.parse(@brokerage_ofx)
      assert length(result.holding_data) == 3
    end

    test "parses holding symbol and quantity" do
      {:ok, result} = OFX.parse(@brokerage_ofx)
      aapl = Enum.find(result.holding_data, &(&1.symbol == "037833100"))
      assert aapl != nil
      assert Decimal.equal?(aapl.quantity, Decimal.new("15.000"))
      assert Decimal.equal?(aapl.current_price, Decimal.new("185.40"))
    end

    test "extracts investment transactions" do
      {:ok, result} = OFX.parse(@brokerage_ofx)
      assert result.transaction_data != []
    end
  end

  describe "parse/1 — error handling" do
    test "returns error for empty string" do
      assert {:error, _reason} = OFX.parse("")
    end

    test "returns error for invalid OFX" do
      assert {:error, _reason} = OFX.parse("this is not ofx data")
    end
  end
end
