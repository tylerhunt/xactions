defmodule Xactions.Sync.SyncWorkerTest do
  use Xactions.DataCase

  alias Xactions.Sync.{SyncWorker, SyncLog}
  alias Xactions.Accounts
  import Xactions.Fixtures

  setup do
    inst = institution!(%{scraper_module: "Xactions.FakeScraper"})
    {:ok, institution: inst}
  end

  describe "sync/1 — success path" do
    test "creates sync log with success status", %{institution: inst} do
      Process.put(:fake_scraper_response, {:ok, fake_result()})
      assert {:ok, _log} = SyncWorker.sync(inst)

      log = Xactions.Repo.one!(from l in SyncLog, where: l.institution_id == ^inst.id)
      assert log.status == "success"
      assert log.completed_at != nil
    end

    test "upserts account from sync result", %{institution: inst} do
      Process.put(:fake_scraper_response, {:ok, fake_result()})
      SyncWorker.sync(inst)

      accounts = Accounts.list_accounts_for_institution(inst.id)
      assert length(accounts) == 1
      assert hd(accounts).name == "Fake Checking"
    end

    test "inserts transactions", %{institution: inst} do
      Process.put(:fake_scraper_response, {:ok, fake_result()})
      SyncWorker.sync(inst)

      account = Accounts.list_accounts_for_institution(inst.id) |> hd()

      count =
        Xactions.Repo.aggregate(
          from(t in Xactions.Transactions.Transaction, where: t.account_id == ^account.id),
          :count
        )

      assert count == 1
    end

    test "deduplicates transactions by fit_id", %{institution: inst} do
      Process.put(:fake_scraper_response, {:ok, fake_result()})
      SyncWorker.sync(inst)
      SyncWorker.sync(inst)

      account = Accounts.list_accounts_for_institution(inst.id) |> hd()

      count =
        Xactions.Repo.aggregate(
          from(t in Xactions.Transactions.Transaction, where: t.account_id == ^account.id),
          :count
        )

      assert count == 1
    end

    test "updates institution last_synced_at", %{institution: inst} do
      Process.put(:fake_scraper_response, {:ok, fake_result()})
      SyncWorker.sync(inst)

      updated = Accounts.get_institution!(inst.id)
      assert updated.last_synced_at != nil
    end
  end

  describe "sync/1 — credential error" do
    test "logs error and updates institution status", %{institution: inst} do
      Process.put(:fake_scraper_response, {:error, :credential_error})
      assert {:error, :credential_error} = SyncWorker.sync(inst)

      log = Xactions.Repo.one!(from l in SyncLog, where: l.institution_id == ^inst.id)
      assert log.status == "error"

      updated = Accounts.get_institution!(inst.id)
      assert updated.status == "credential_error"
    end
  end

  describe "sync/1 — MFA required" do
    test "returns mfa_required and logs accordingly", %{institution: inst} do
      Process.put(:fake_scraper_response, {:error, :mfa_required, :sms})
      assert {:error, :mfa_required, :sms} = SyncWorker.sync(inst)

      updated = Accounts.get_institution!(inst.id)
      assert updated.status == "mfa_required"
    end
  end

  defp fake_result do
    %{
      accounts: [
        %{
          external_account_id: "ACC001",
          name: "Fake Checking",
          type: "checking",
          balance: Decimal.new("1234.56"),
          currency: "USD"
        }
      ],
      transactions: [
        %{
          fit_id: "TXN001",
          date: Date.utc_today(),
          amount: Decimal.new("-42.00"),
          merchant_name: "FAKE MERCHANT",
          raw_merchant: "FAKE MERCHANT 12345",
          is_pending: false
        }
      ],
      holdings: []
    }
  end
end
