# Contract: Scraper Behaviour

**Type**: Elixir behaviour (`@behaviour Xactions.Sync.ScraperBehaviour`)
**Purpose**: Defines the interface each institution-specific scraper module must implement.

All scraper modules live under `Xactions.Sync.Scrapers.*` and must implement this
behaviour. This contract decouples the sync orchestration (`SyncWorker`) from
institution-specific navigation logic.

---

## Behaviour Definition

```elixir
defmodule Xactions.Sync.ScraperBehaviour do
  @type institution :: %Xactions.Accounts.Institution{}
  @type browser_context :: Playwright.BrowserContext.t()

  @type sync_result :: %{
    accounts: [account_data()],
    transactions: [transaction_data()],
    holdings: [holding_data()]
  }

  @type account_data :: %{
    external_account_id: String.t(),
    name: String.t(),
    type: :checking | :savings | :brokerage | :credit_card | :loan | :mortgage,
    balance: Decimal.t(),
    currency: String.t()
  }

  @type transaction_data :: %{
    external_account_id: String.t(),
    fit_id: String.t(),
    date: Date.t(),
    amount: Decimal.t(),
    raw_merchant: String.t() | nil,
    is_pending: boolean()
  }

  @type holding_data :: %{
    external_account_id: String.t(),
    symbol: String.t() | nil,
    name: String.t(),
    quantity: Decimal.t(),
    cost_basis: Decimal.t() | nil,
    current_price: Decimal.t() | nil,
    asset_class: :stock | :etf | :mutual_fund | :bond | :cash | :other,
    external_security_id: String.t() | nil
  }

  @doc """
  Perform a full sync for the institution. The scraper MUST:
  1. Log in using credentials from `institution` (already decrypted by SyncWorker).
  2. Download transaction exports for all accounts.
  3. Download investment holdings if applicable.
  4. Return structured data or an error tuple.

  The browser_context is provided pre-initialized by SyncWorker. The scraper MUST
  NOT close it — SyncWorker manages the browser lifecycle.
  """
  @callback sync(institution(), browser_context()) ::
    {:ok, sync_result()}
    | {:error, :credential_error}
    | {:error, :mfa_required, mfa_type :: :totp | :sms | :push}
    | {:error, :export_unavailable}
    | {:error, reason :: String.t()}

  @doc """
  Resolve an MFA challenge using a user-supplied code. Called after the user
  submits a code via MfaLive. The browser_context retains state from the
  suspended `sync/2` call.
  """
  @callback resolve_mfa(browser_context(), code :: String.t()) ::
    {:ok, sync_result()}
    | {:error, :invalid_code}
    | {:error, reason :: String.t()}

  @doc """
  Return a human-readable name for display in the UI.
  """
  @callback name() :: String.t()

  @doc """
  Return the export format this scraper produces.
  Values: :ofx | :qfx | :csv
  """
  @callback export_format() :: :ofx | :qfx | :csv
end
```

---

## SyncWorker ↔ Scraper Protocol

```
SyncWorker                         Scraper Module
    │                                   │
    │── decrypt credentials ───────────▶│
    │── open_browser_context() ─────────▶│
    │                                   │
    │── scraper.sync(institution, ctx) ─▶│
    │                                   │── navigate to login page
    │                                   │── enter credentials
    │                                   │── detect MFA challenge?
    │                                   │     ├─ TOTP: generate code, submit
    │                                   │     └─ SMS/Push: return {:error, :mfa_required, :sms}
    │◀── {:error, :mfa_required, :sms} ─│
    │                                   │
    │── broadcast {:mfa_required, id} ──▶ PubSub
    │── wait for MFA code from user ────▶ (GenServer state)
    │                                   │
    │── scraper.resolve_mfa(ctx, code) ─▶│
    │◀── {:ok, sync_result} ────────────│
    │                                   │
    │── close_browser_context() ────────▶│
    │── persist transactions/accounts ──▶ Repo
    │── write SyncLog ─────────────────▶ Repo
    │── broadcast {:sync_complete, id} ─▶ PubSub
```

---

## OFX Direct Connect (Alternative Sync Method)

When `institution.sync_method == :ofx_direct`, the scraper skips Playwright entirely
and makes a direct HTTP POST to the institution's OFX server URL using `Req`. The
request uses OFX SGML format:

**Request format** (simplified):

```
OFXHEADER:100
DATA:OFXSGML
VERSION:102
SECURITY:NONE
ENCODING:USASCII
CHARSET:1252
COMPRESSION:NONE
OLDFILEUID:NONE
NEWFILEUID:NONE

<OFX>
  <SIGNONMSGSRQV1>
    <SONRQ>
      <DTCLIENT>20260409120000</DTCLIENT>
      <USERID>{username}</USERID>
      <USERPASS>{password}</USERPASS>
      <LANGUAGE>ENG</LANGUAGE>
      <FI>
        <ORG>{institution_org}</ORG>
        <FID>{institution_fid}</FID>
      </FI>
      <APPID>QWIN</APPID>
      <APPVER>2700</APPVER>
    </SONRQ>
  </SIGNONMSGSRQV1>
  <BANKMSGSRQV1>
    <STMTTRNRQ>
      <TRNUID>1</TRNUID>
      <STMTRQ>
        <BANKACCTFROM>
          <BANKID>{routing_number}</BANKID>
          <ACCTID>{account_number}</ACCTID>
          <ACCTTYPE>CHECKING</ACCTTYPE>
        </BANKACCTFROM>
        <INCTRAN>
          <DTSTART>20260301</DTSTART>
          <INCLUDE>Y</INCLUDE>
        </INCTRAN>
      </STMTRQ>
    </STMTTRNRQ>
  </BANKMSGSRQV1>
</OFX>
```

**Additional Institution fields for OFX Direct Connect**:

| Field | Type | Notes |
|-------|------|-------|
| `ofx_org` | string | Institution OFX `<ORG>` identifier |
| `ofx_fid` | string | Institution OFX `<FID>` identifier |

These fields are nullable in the schema and only required when `sync_method: :ofx_direct`.

---

## OFX Parser Interface

```elixir
defmodule Xactions.Sync.OFX do
  @doc """
  Parse an OFX 1.x (SGML) or OFX 2.x (XML) binary and return structured data.
  """
  @spec parse(binary()) ::
    {:ok, %{
      accounts: [account_data()],
      transactions: [transaction_data()],
      holdings: [holding_data()]
    }}
    | {:error, reason :: String.t()}

  @doc """
  Detect whether the binary is OFX 1.x SGML or OFX 2.x XML.
  """
  @spec format(binary()) :: :ofx_sgml | :ofx_xml | :unknown
end
```
