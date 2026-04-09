defmodule Xactions.Transactions do
  @moduledoc """
  Context for viewing, categorizing, and managing transactions.
  """

  import Ecto.Query

  alias Xactions.{Repo, Accounts}
  alias Xactions.Transactions.{Transaction, TransactionSplit, MerchantRule, Category}

  @page_size 50

  @doc """
  Lists transactions with optional filters.

  Accepted filter keys (all optional):
    - `:account_id` — filter by account
    - `:category_id` — filter by category
    - `:date_from` — earliest date (inclusive)
    - `:date_to` — latest date (inclusive)
    - `:query` — case-insensitive merchant name substring match
    - `:limit` — rows per page (default 50)
    - `:offset` — row offset for pagination (default 0)
  """
  def list_transactions(filters \\ %{}) do
    limit = Map.get(filters, :limit, @page_size)
    offset = Map.get(filters, :offset, 0)

    Transaction
    |> apply_filters(filters)
    |> order_by([t], desc: t.date, desc: t.inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> preload([:category, :splits])
    |> Repo.all()
  end

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:account_id, id}, q when not is_nil(id) ->
        where(q, [t], t.account_id == ^id)

      {:category_id, id}, q when not is_nil(id) ->
        where(q, [t], t.category_id == ^id)

      {:date_from, date}, q when not is_nil(date) ->
        where(q, [t], t.date >= ^date)

      {:date_to, date}, q when not is_nil(date) ->
        where(q, [t], t.date <= ^date)

      {:query, q_str}, q when is_binary(q_str) and q_str != "" ->
        like = "%#{String.downcase(q_str)}%"
        where(q, [t], like(fragment("LOWER(?)", t.merchant_name), ^like))

      _, q ->
        q
    end)
  end

  @doc """
  Updates the category on a transaction and upserts a merchant rule based on the
  normalized merchant name.
  """
  def update_category(%Transaction{} = txn, category_id) do
    Repo.transaction(fn ->
      {:ok, updated} =
        txn
        |> Transaction.changeset(%{category_id: category_id})
        |> Repo.update()

      if txn.merchant_name do
        pattern = MerchantRule.normalize_merchant(txn.merchant_name)

        if pattern && pattern != "" do
          Repo.insert!(
            %MerchantRule{merchant_pattern: pattern, category_id: category_id},
            on_conflict: [set: [category_id: category_id]],
            conflict_target: :merchant_pattern
          )
        end
      end

      updated
    end)
  end

  @doc """
  Splits a transaction into multiple categorized parts.

  Validates:
  - At least 2 splits
  - Split amounts sum exactly to the parent transaction amount
  """
  def split_transaction(%Transaction{}, splits) when length(splits) < 2 do
    {:error, :min_splits}
  end

  def split_transaction(%Transaction{} = txn, splits) do
    total =
      Enum.reduce(splits, Decimal.new("0"), fn s, acc ->
        amount = parse_decimal(Map.get(s, "amount", "0"))
        Decimal.add(acc, amount)
      end)

    if Decimal.compare(total, txn.amount) != :eq do
      {:error, :amount_mismatch}
    else
      Repo.transaction(fn ->
        Repo.delete_all(from s in TransactionSplit, where: s.transaction_id == ^txn.id)

        for split <- splits do
          Repo.insert!(%TransactionSplit{
            transaction_id: txn.id,
            category_id: parse_int(Map.get(split, "category_id")),
            amount: parse_decimal(Map.get(split, "amount", "0")),
            notes: Map.get(split, "notes")
          })
        end

        {:ok, updated} =
          txn
          |> Transaction.changeset(%{is_split: true, category_id: nil})
          |> Repo.update()

        %{transaction: updated}
      end)
    end
  end

  @doc """
  Adds a manual transaction. Validates that the account is a manual account.
  """
  def add_manual_transaction(attrs) do
    account_id = Map.get(attrs, :account_id) || Map.get(attrs, "account_id")
    account = account_id && Accounts.get_account!(account_id)

    if account && account.is_manual do
      %Transaction{}
      |> Transaction.changeset(Map.put(attrs, :is_manual, true))
      |> Repo.insert()
    else
      {:error, :not_manual_account}
    end
  end

  @doc """
  Applies merchant category rules to a transaction. Returns `{:ok, transaction}`
  with category set if a rule matched, or unchanged if no rule found.
  """
  def apply_merchant_rules(%Transaction{merchant_name: nil} = txn), do: {:ok, txn}

  def apply_merchant_rules(%Transaction{} = txn) do
    pattern = MerchantRule.normalize_merchant(txn.merchant_name)

    case pattern && Repo.get_by(MerchantRule, merchant_pattern: pattern) do
      %MerchantRule{category_id: cat_id} ->
        txn
        |> Transaction.changeset(%{category_id: cat_id})
        |> Repo.update()

      nil ->
        {:ok, txn}
    end
  end

  @doc """
  Returns all categories for dropdown rendering.
  """
  def list_categories do
    Repo.all(from c in Category, order_by: [asc: c.name])
  end

  defp parse_decimal(val) when is_binary(val), do: Decimal.new(val)
  defp parse_decimal(%Decimal{} = d), do: d
  defp parse_decimal(val), do: Decimal.new(to_string(val))

  defp parse_int(val) when is_integer(val), do: val
  defp parse_int(val) when is_binary(val), do: String.to_integer(val)
  defp parse_int(val), do: val
end
