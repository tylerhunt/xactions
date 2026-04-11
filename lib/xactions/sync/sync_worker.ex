defmodule Xactions.Sync.SyncWorker do
  @moduledoc """
  Runs a single sync for one institution.

  Decrypts credentials, calls the institution's scraper module,
  parses the result, upserts accounts + transactions, writes a SyncLog,
  and broadcasts PubSub status events.
  """

  require Logger
  import Ecto.Query

  alias Xactions.{Repo, Accounts}
  alias Xactions.Accounts.Institution
  alias Xactions.Transactions.Transaction
  alias Xactions.Sync.SyncLog

  def sync(%Institution{} = institution) do
    do_sync(institution)
  rescue
    e ->
      Logger.error("[SyncWorker] Unexpected error for institution #{institution.id}: #{Exception.message(e)}")
      {:error, :unexpected}
  end

  defp do_sync(%Institution{} = institution) do
    log = start_log(institution)
    {:ok, _} = Accounts.update_institution_status(institution, "syncing")
    broadcast(institution.id, :sync_started)

    scraper = resolve_scraper(institution)

    case scraper.sync(institution, %{}) do
      {:ok, result} ->
        handle_success(institution, log, result)

      {:error, :mfa_required, mfa_type} ->
        {:ok, _} = Accounts.update_institution_status(institution, "mfa_required")
        finish_log(log, "mfa_required", %{error_message: "MFA required: #{mfa_type}"})
        broadcast(institution.id, {:mfa_required, mfa_type})
        {:error, :mfa_required, mfa_type}

      {:error, :credential_error} ->
        {:ok, _} = Accounts.update_institution_status(institution, "credential_error")
        finish_log(log, "error", %{error_message: "Credential error"})
        broadcast(institution.id, :credential_error)
        {:error, :credential_error}

      {:error, reason} ->
        {:ok, _} = Accounts.update_institution_status(institution, "error")
        finish_log(log, "error", %{error_message: to_string(reason)})
        broadcast(institution.id, {:sync_error, reason})
        {:error, reason}
    end
  end

  defp handle_success(institution, log, result) do
    {accounts_updated, transactions_added, transactions_modified} =
      upsert_result(institution, result)

    {:ok, _} = Accounts.update_institution_status(institution, "active")
    {:ok, _} = Accounts.touch_synced_at(institution)

    finished_log =
      finish_log(log, "success", %{
        accounts_updated: accounts_updated,
        transactions_added: transactions_added,
        transactions_modified: transactions_modified
      })

    broadcast(institution.id, :sync_complete)
    {:ok, finished_log}
  end

  defp upsert_result(institution, %{accounts: accounts, transactions: transactions}) do
    accounts_updated = length(accounts)

    account_map =
      Enum.reduce(accounts, %{}, fn acct_attrs, acc ->
        {:ok, account} = Accounts.upsert_account(institution.id, acct_attrs)
        Map.put(acc, acct_attrs.external_account_id, account)
      end)

    {added, modified} =
      Enum.reduce(transactions, {0, 0}, fn txn_attrs, {add_acc, mod_acc} ->
        account = account_for_transaction(account_map, institution, txn_attrs)
        if account, do: upsert_transaction(account.id, txn_attrs, add_acc, mod_acc),
                    else: {add_acc, mod_acc}
      end)

    {accounts_updated, added, modified}
  end

  defp account_for_transaction(account_map, institution, txn_attrs) do
    case Map.values(account_map) do
      [single] -> single
      _ ->
        ext_id = Map.get(txn_attrs, :external_account_id)
        if ext_id, do: Map.get(account_map, ext_id), else: hd(Map.values(account_map))
    end
  end

  defp upsert_transaction(account_id, attrs, add_acc, mod_acc) do
    fit_id = Map.get(attrs, :fit_id)

    existing =
      if fit_id do
        Repo.one(
          from t in Transaction,
            where: t.account_id == ^account_id and t.fit_id == ^fit_id
        )
      end

    case existing do
      nil ->
        %Transaction{}
        |> Transaction.changeset(Map.put(attrs, :account_id, account_id))
        |> Repo.insert!()

        {add_acc + 1, mod_acc}

      txn ->
        if txn.is_pending do
          txn
          |> Transaction.changeset(%{amount: attrs.amount, is_pending: false})
          |> Repo.update!()

          {add_acc, mod_acc + 1}
        else
          {add_acc, mod_acc}
        end
    end
  end

  defp resolve_scraper(%Institution{scraper_module: mod}) when is_binary(mod) do
    String.to_existing_atom("Elixir.#{mod}")
  rescue
    e -> reraise "Unknown scraper module: #{mod}", __STACKTRACE__
  end

  defp start_log(institution) do
    Repo.insert!(%SyncLog{
      institution_id: institution.id,
      status: "running",
      started_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  defp finish_log(log, status, attrs) do
    log
    |> SyncLog.changeset(
      Map.merge(attrs, %{
        status: status,
        completed_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
    )
    |> Repo.update!()
  end

  defp broadcast(institution_id, event) do
    Phoenix.PubSub.broadcast(
      Xactions.PubSub,
      "sync:status",
      {event, institution_id}
    )
  end
end
