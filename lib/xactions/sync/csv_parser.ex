defmodule Xactions.Sync.CSVParser do
  @moduledoc """
  Parses CSV exports from financial institutions.

  Each institution provides a `column_map` describing which CSV header
  maps to which normalized field:

      %{
        date: "Date",
        merchant_name: "Description",
        amount: "Amount"
      }
  """

  NimbleCSV.define(Xactions.Sync.CSVParser.RFC4180, separator: ",", escape: "\"")

  alias Xactions.Sync.CSVParser.RFC4180

  @required_fields [:date, :merchant_name, :amount]

  def parse(content, column_map) when is_binary(content) and content != "" do
    with :ok <- validate_column_map(column_map),
         {:ok, rows} <- parse_csv(content),
         {:ok, [header | data_rows]} <- {:ok, rows},
         :ok <- validate_headers(header, column_map) do
      transactions =
        data_rows
        |> Enum.reject(&all_blank?/1)
        |> Enum.map(&row_to_transaction(&1, header, column_map))
        |> Enum.reject(&is_nil/1)

      {:ok, transactions}
    end
  end

  def parse("", _column_map), do: {:error, "empty CSV content"}
  def parse(_, _), do: {:error, "invalid input"}

  defp validate_column_map(column_map) do
    missing = @required_fields -- Map.keys(column_map)

    if missing == [] do
      :ok
    else
      {:error, "column_map missing required fields: #{inspect(missing)}"}
    end
  end

  defp parse_csv(content) do
    rows = RFC4180.parse_string(content, skip_headers: false)
    {:ok, rows}
  rescue
    _ -> {:error, "CSV parse error"}
  end

  defp validate_headers(header_row, column_map) do
    missing =
      @required_fields
      |> Enum.map(&Map.get(column_map, &1))
      |> Enum.reject(&(&1 in header_row))

    if missing == [] do
      :ok
    else
      {:error, "CSV missing required columns: #{inspect(missing)}"}
    end
  end

  defp row_to_transaction(row, header, column_map) do
    get = fn field ->
      col = Map.get(column_map, field)
      idx = Enum.find_index(header, &(&1 == col))
      if idx, do: Enum.at(row, idx), else: nil
    end

    date_str = get.(:date)
    amount_str = get.(:amount)
    merchant = get.(:merchant_name)

    with {:ok, date} <- parse_date(date_str),
         {:ok, amount} <- parse_decimal(amount_str) do
      %{
        date: date,
        amount: amount,
        merchant_name: merchant,
        raw_merchant: merchant,
        is_pending: false
      }
    else
      _ -> nil
    end
  end

  defp parse_date(nil), do: {:error, :nil_date}
  defp parse_date(str) do
    case Date.from_iso8601(String.trim(str)) do
      {:ok, d} -> {:ok, d}
      _ ->
        case Regex.run(~r|(\d{1,2})/(\d{1,2})/(\d{4})|, str) do
          [_, m, d, y] ->
            Date.new(String.to_integer(y), String.to_integer(m), String.to_integer(d))
          _ -> {:error, :invalid_date}
        end
    end
  end

  defp parse_decimal(nil), do: {:error, :nil_amount}
  defp parse_decimal(str) do
    str = str |> String.trim() |> String.replace(",", "")
    case Decimal.parse(str) do
      {d, ""} -> {:ok, d}
      {d, _} -> {:ok, d}
      :error -> {:error, :invalid_decimal}
    end
  end

  defp all_blank?(row), do: Enum.all?(row, &(String.trim(&1) == ""))
end
