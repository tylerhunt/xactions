defmodule Xactions.FakeScraper do
  @moduledoc """
  A test double implementing `ScraperBehaviour`.
  Configure responses via the process dictionary before calling sync/2.

  ## Usage

      Process.put(:fake_scraper_response, {:ok, result})
      Process.put(:fake_scraper_response, {:error, :credential_error})
      Process.put(:fake_scraper_response, {:error, :mfa_required, :totp})
  """

  @behaviour Xactions.Sync.ScraperBehaviour

  @impl true
  def name, do: "Fake Bank"

  @impl true
  def export_format, do: :ofx

  @impl true
  def sync(_institution, _browser_context) do
    case Process.get(:fake_scraper_response, default_success()) do
      {:error, :mfa_required, mfa_type} -> {:error, :mfa_required, mfa_type}
      other -> other
    end
  end

  @impl true
  def resolve_mfa(_browser_context, _code) do
    Process.get(:fake_scraper_mfa_response, default_success())
  end

  defp default_success do
    {:ok,
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
     }}
  end
end
