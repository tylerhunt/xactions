defmodule Xactions.Sync.OFX do
  @moduledoc """
  Parses OFX 1.x SGML and 2.x XML exports.

  Returns structured maps compatible with `SyncWorker` upsert logic.
  """

  def parse(content) when is_binary(content) and content != "" do
    cond do
      String.contains?(content, "OFXHEADER") -> parse_sgml(content)
      String.contains?(content, "<?OFX") -> parse_xml(content)
      String.contains?(content, "<OFX>") -> parse_xml(content)
      true -> {:error, "unrecognized OFX format"}
    end
  end

  def parse(""), do: {:error, "empty content"}
  def parse(_), do: {:error, "invalid input"}

  # --- SGML (OFX 1.x) ---

  defp parse_sgml(content) do
    body = extract_sgml_body(content)

    with {:ok, account_data} <- extract_account(body),
         transaction_data = extract_transactions(body),
         holding_data = extract_holdings(body) do
      {:ok, %{account_data: account_data, transaction_data: transaction_data, holding_data: holding_data}}
    end
  end

  defp extract_sgml_body(content) do
    case String.split(content, ~r/\n\n|\r\n\r\n/, parts: 2) do
      [_header, body] -> body
      [body] -> body
    end
  end

  defp extract_account(body) do
    cond do
      String.contains?(body, "<STMTRS>") -> extract_bank_account(body)
      String.contains?(body, "<CCSTMTRS>") -> extract_cc_account(body)
      String.contains?(body, "<INVSTMTRS>") -> extract_inv_account(body)
      true -> {:error, "no account statement found"}
    end
  end

  defp extract_bank_account(body) do
    acct_type =
      body
      |> tag_value("ACCTTYPE")
      |> normalize_account_type()

    balance =
      body
      |> find_in_tag("LEDGERBAL", "BALAMT")
      |> parse_decimal()

    acct_id = tag_value(body, "ACCTID")

    {:ok, %{type: acct_type, external_account_id: acct_id, balance: balance, currency: "USD"}}
  end

  defp extract_cc_account(body) do
    balance =
      body
      |> find_in_tag("LEDGERBAL", "BALAMT")
      |> parse_decimal()

    acct_id = tag_value(body, "ACCTID")

    {:ok, %{type: "credit_card", external_account_id: acct_id, balance: balance, currency: "USD"}}
  end

  defp extract_inv_account(body) do
    acct_id = tag_value(body, "ACCTID")
    cash = body |> tag_value("AVAILCASH") |> parse_decimal()
    balance = cash || Decimal.new("0")

    {:ok, %{type: "brokerage", external_account_id: acct_id, balance: balance, currency: "USD"}}
  end

  defp extract_transactions(body) do
    txn_block = extract_between(body, "BANKTRANLIST") || extract_between(body, "INVTRANLIST") || ""

    ~r/<STMTTRN>(.*?)<\/STMTTRN>|<STMTTRN>(.*?)(?=<STMTTRN>|<\/BANKTRANLIST>)/s
    |> Regex.scan(txn_block)
    |> Enum.map(fn
      [_, block, ""] -> parse_sgml_transaction(block)
      [_, "", block] -> parse_sgml_transaction(block)
      [_, block] -> parse_sgml_transaction(block)
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.concat(extract_inv_transactions(body))
  end

  defp extract_inv_transactions(body) do
    ~r/<BUYSTOCK>(.*?)<\/BUYSTOCK>/s
    |> Regex.scan(body)
    |> Enum.map(fn [_, block] ->
      invtran = extract_between(block, "INVTRAN") || block

      %{
        fit_id: tag_value(invtran, "FITID"),
        date: invtran |> tag_value("DTTRADE") |> parse_ofx_date(),
        amount: block |> tag_value("TOTAL") |> parse_decimal() || Decimal.new("0"),
        merchant_name: tag_value(invtran, "MEMO"),
        raw_merchant: tag_value(invtran, "MEMO"),
        is_pending: false
      }
    end)
    |> Enum.reject(&is_nil(&1.fit_id))
  end

  defp parse_sgml_transaction(block) do
    fit_id = tag_value(block, "FITID")
    return_nil_if_blank(fit_id, fn ->
      %{
        fit_id: fit_id,
        date: block |> tag_value("DTPOSTED") |> parse_ofx_date(),
        amount: block |> tag_value("TRNAMT") |> parse_decimal(),
        merchant_name: tag_value(block, "NAME"),
        raw_merchant: tag_value(block, "MEMO"),
        is_pending: false
      }
    end)
  end

  defp extract_holdings(body) do
    ~r/<POSSTOCK>(.*?)<\/POSSTOCK>/s
    |> Regex.scan(body)
    |> Enum.map(fn [_, block] ->
      invpos = extract_between(block, "INVPOS") || block
      secid = extract_between(block, "SECID") || block

      symbol = tag_value(secid, "UNIQUEID")
      return_nil_if_blank(symbol, fn ->
        %{
          symbol: symbol,
          quantity: invpos |> tag_value("UNITS") |> parse_decimal(),
          current_price: invpos |> tag_value("UNITPRICE") |> parse_decimal(),
          price_as_of: invpos |> tag_value("DTPRICEASOF") |> parse_ofx_datetime(),
          asset_class: "equity"
        }
      end)
    end)
    |> Enum.reject(&is_nil/1)
  end

  # --- XML (OFX 2.x) ---

  defp parse_xml(_content) do
    # OFX 2.x is valid XML — delegate to SGML parser after stripping XML header
    {:error, "OFX 2.x XML not yet supported"}
  end

  # --- Helpers ---

  defp tag_value(content, tag) do
    case Regex.run(~r/<#{tag}>\s*([^<\n\r]+)/, content) do
      [_, value] -> String.trim(value)
      _ -> nil
    end
  end

  defp find_in_tag(content, outer_tag, inner_tag) do
    case extract_between(content, outer_tag) do
      nil -> nil
      block -> tag_value(block, inner_tag)
    end
  end

  defp extract_between(content, tag) do
    case Regex.run(~r/<#{tag}>(.*?)<\/#{tag}>/s, content) do
      [_, inner] -> inner
      _ ->
        case Regex.run(~r/<#{tag}>(.*?)(?=<\/|<[A-Z])/s, content) do
          [_, inner] -> inner
          _ -> nil
        end
    end
  end

  defp normalize_account_type("CHECKING"), do: "checking"
  defp normalize_account_type("SAVINGS"), do: "savings"
  defp normalize_account_type("CREDITLINE"), do: "credit_card"
  defp normalize_account_type("MONEYMRKT"), do: "savings"
  defp normalize_account_type(_), do: "checking"

  defp parse_decimal(nil), do: nil
  defp parse_decimal(""), do: nil
  defp parse_decimal(str) when is_binary(str) do
    str = String.trim(str)
    case Decimal.parse(str) do
      {d, ""} -> d
      {d, _} -> d
      :error -> nil
    end
  end

  defp parse_ofx_date(nil), do: nil
  defp parse_ofx_date(str) when is_binary(str) do
    str = String.trim(str)
    case str do
      <<y::binary-size(4), m::binary-size(2), d::binary-size(2), _::binary>> ->
        case Date.new(String.to_integer(y), String.to_integer(m), String.to_integer(d)) do
          {:ok, date} -> date
          _ -> nil
        end
      _ -> nil
    end
  end

  defp parse_ofx_datetime(nil), do: nil
  defp parse_ofx_datetime(str) when is_binary(str) do
    case parse_ofx_date(str) do
      %Date{} = d -> DateTime.new!(d, ~T[12:00:00], "Etc/UTC")
      _ -> nil
    end
  end

  defp return_nil_if_blank(nil, _fun), do: nil
  defp return_nil_if_blank("", _fun), do: nil
  defp return_nil_if_blank(_val, fun), do: fun.()
end
