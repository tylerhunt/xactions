defmodule Xactions.Sync.Scrapers.ExampleBank do
  @moduledoc """
  Example scraper showing the Playwright navigation pattern.

  Copy this file to implement a new institution scraper.
  Name it after the institution (e.g., `chase.ex`, `fidelity.ex`).

  ## Steps to implement a new scraper

  1. Copy this file to `lib/xactions/sync/scrapers/your_bank.ex`
  2. Update `name/0` and `export_format/0`
  3. Implement `sync/2`:
     - Navigate to the login page
     - Submit credentials from `institution.credential_username` / `credential_password`
     - Handle MFA (return `{:error, :mfa_required, :totp | :sms | :push}`)
     - Navigate to the export page and download the file
     - Parse using `Xactions.Sync.OFX.parse/1` or `Xactions.Sync.CSVParser.parse/2`
     - Return `{:ok, result}`
  4. Implement `resolve_mfa/2` for SMS/push flows
  5. Register the module name in the institution record's `scraper_module` field

  ## Playwright usage

  The `browser_context` map contains a connected Playwright browser context.
  Use the `Playwright` hex package to control the browser:

      page = Playwright.BrowserContext.new_page(browser_context)
      Playwright.Page.goto(page, "https://yourbank.com/login")
      Playwright.Page.fill(page, "#username", institution.credential_username)
      Playwright.Page.fill(page, "#password", institution.credential_password)
      Playwright.Page.click(page, "#submit")

  ## OFX Direct Connect (faster alternative)

  If the bank supports OFX Direct Connect, set `sync_method: "ofx_direct"` on
  the institution and implement the HTTP POST in `sync/2` using `Req`:

      Req.post!(institution.ofx_direct_url,
        body: ofx_request_body(institution),
        headers: [{"Content-Type", "application/x-ofx"}]
      )
  """

  @behaviour Xactions.Sync.ScraperBehaviour

  @impl true
  def name, do: "Example Bank"

  @impl true
  def export_format, do: :ofx

  @impl true
  def sync(_institution, _browser_context) do
    # Replace with real Playwright navigation:
    #
    #   page = Playwright.BrowserContext.new_page(browser_context)
    #   Playwright.Page.goto(page, "https://example-bank.com/login")
    #   Playwright.Page.fill(page, "#user", institution.credential_username)
    #   Playwright.Page.fill(page, "#pass", institution.credential_password)
    #   Playwright.Page.click(page, "button[type=submit]")
    #
    #   case detect_mfa(page) do
    #     :totp ->
    #       code = NimbleTOTP.verification_code(institution.totp_seed)
    #       Playwright.Page.fill(page, "#totp", code)
    #       Playwright.Page.click(page, "#verify")
    #     :sms -> return {:error, :mfa_required, :sms}
    #     nil -> :ok
    #   end
    #
    #   ofx_content = download_ofx(page)
    #   {:ok, result} = Xactions.Sync.OFX.parse(ofx_content)
    #   {:ok, result}

    {:error, "ExampleBank is a stub — implement sync/2 for a real institution"}
  end

  @impl true
  def resolve_mfa(_browser_context, _code) do
    # Submit MFA code and resume export download
    {:error, "ExampleBank is a stub — implement resolve_mfa/2"}
  end
end
