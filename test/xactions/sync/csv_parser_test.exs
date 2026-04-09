defmodule Xactions.Sync.CSVParserTest do
  use ExUnit.Case, async: true

  alias Xactions.Sync.CSVParser

  @sample_csv """
  Date,Description,Amount,Balance
  2026-04-05,WHOLE FOODS MARKET,-52.34,4823.17
  2026-04-04,NETFLIX.COM,-15.99,4875.51
  2026-04-01,DIRECT DEPOSIT,3500.00,4891.50
  """

  @column_map %{
    date: "Date",
    merchant_name: "Description",
    amount: "Amount"
  }

  describe "parse/2" do
    test "returns ok tuple with transaction list" do
      assert {:ok, transactions} = CSVParser.parse(@sample_csv, @column_map)
      assert length(transactions) == 3
    end

    test "parses date field" do
      {:ok, transactions} = CSVParser.parse(@sample_csv, @column_map)
      txn = Enum.find(transactions, &(&1.merchant_name == "WHOLE FOODS MARKET"))
      assert txn.date == ~D[2026-04-05]
    end

    test "parses amount as Decimal" do
      {:ok, transactions} = CSVParser.parse(@sample_csv, @column_map)
      txn = Enum.find(transactions, &(&1.merchant_name == "NETFLIX.COM"))
      assert Decimal.equal?(txn.amount, Decimal.new("-15.99"))
    end

    test "parses positive credit amounts" do
      {:ok, transactions} = CSVParser.parse(@sample_csv, @column_map)
      txn = Enum.find(transactions, &(&1.merchant_name == "DIRECT DEPOSIT"))
      assert Decimal.positive?(txn.amount)
    end

    test "returns error for empty CSV" do
      assert {:error, _} = CSVParser.parse("", @column_map)
    end

    test "returns error when required column is missing" do
      bad_map = %{date: "Date", merchant_name: "NONEXISTENT", amount: "Amount"}
      assert {:error, _} = CSVParser.parse(@sample_csv, bad_map)
    end

    test "skips blank rows" do
      csv_with_blanks = @sample_csv <> "\n\n"
      {:ok, transactions} = CSVParser.parse(csv_with_blanks, @column_map)
      assert length(transactions) == 3
    end
  end
end
