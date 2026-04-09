defmodule Xactions.Sync.ScraperBehaviour do
  @moduledoc """
  Behaviour that all institution scraper modules must implement.

  ## Sync flow

  1. `SyncWorker` calls `sync/2` with the decrypted institution and a browser context.
  2. The scraper navigates to the institution, logs in, and downloads an export.
  3. On success, the scraper returns `{:ok, sync_result()}`.
  4. On MFA: the scraper returns `{:error, :mfa_required, mfa_type}`.
     `MFACoordinator` then pauses the worker and waits for `resolve_mfa/2`.
  5. On TOTP: the scraper auto-resolves using `NimbleTOTP` and the `totp_seed`.

  ## Example

      defmodule Xactions.Sync.Scrapers.MyBank do
        @behaviour Xactions.Sync.ScraperBehaviour

        @impl true
        def name, do: "My Bank"

        @impl true
        def export_format, do: :ofx

        @impl true
        def sync(institution, browser_context) do
          # Navigate, log in, download OFX
          {:ok, %{accounts: [...], transactions: [...], holdings: []}}
        end

        @impl true
        def resolve_mfa(browser_context, code) do
          # Submit MFA code and resume download
          {:ok, %{accounts: [...], transactions: [...], holdings: []}}
        end
      end
  """

  @type institution :: %Xactions.Accounts.Institution{}
  @type browser_context :: map()
  @type sync_result :: %{
          accounts: list(map()),
          transactions: list(map()),
          holdings: list(map())
        }

  @doc "Human-readable name for this institution."
  @callback name() :: String.t()

  @doc "File format exported by this scraper."
  @callback export_format() :: :ofx | :qfx | :csv

  @doc """
  Perform a full sync for the given institution.

  Returns `{:ok, sync_result()}` on success, or one of:
  - `{:error, :credential_error}` — bad username/password
  - `{:error, :mfa_required, :totp | :sms | :push}` — MFA needed
  - `{:error, :export_unavailable}` — export page/format not available
  - `{:error, reason}` — any other error
  """
  @callback sync(institution(), browser_context()) ::
              {:ok, sync_result()}
              | {:error, :credential_error}
              | {:error, :mfa_required, mfa_type :: :totp | :sms | :push}
              | {:error, :export_unavailable}
              | {:error, reason :: String.t()}

  @doc """
  Resume sync after an MFA code has been provided.

  Called by `MFACoordinator` after the user submits their SMS/push code.
  """
  @callback resolve_mfa(browser_context(), code :: String.t()) ::
              {:ok, sync_result()}
              | {:error, :invalid_code}
              | {:error, reason :: String.t()}
end
