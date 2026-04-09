# Data Model: Personal Accounting with Multi-Institution Sync

**Branch**: `001-personal-accounting` | **Date**: 2026-04-09

## Entity Relationship Summary

```
Institution ──< Account ──< Transaction ──< TransactionSplit
     │              │               │
     │              │               └─> Category <── MerchantCategoryRule
     │              └──< Holding
     └──< SyncLog

Category ──< BudgetTarget
```

---

## Entities

### Institution

Represents a financial institution the user has configured for automated sync or manual
entry. Stores encrypted login credentials used by the headless browser scraper.

| Field | Type | Constraints | Notes |
|-------|------|-------------|-------|
| `id` | integer | PK, auto-increment | |
| `name` | string | NOT NULL | Display name (e.g., "Chase", "Fidelity") |
| `website_url` | string | nullable | URL of institution's login page |
| `scraper_module` | string | NOT NULL | Elixir module name implementing `SyncBehaviour` (e.g., `"Xactions.Sync.Scrapers.Chase"`) |
| `sync_method` | enum | NOT NULL, default: `browser` | Values: `browser` (Playwright), `ofx_direct` (OFX Direct Connect URL) |
| `ofx_direct_url` | string | nullable | OFX Direct Connect endpoint (when `sync_method: ofx_direct`) |
| `export_format` | enum | NOT NULL, default: `ofx` | Values: `ofx`, `qfx`, `csv` |
| `credential_username` | binary | nullable, encrypted | Bank username — AES-256-GCM encrypted |
| `credential_password` | binary | nullable, encrypted | Bank password — AES-256-GCM encrypted |
| `totp_seed` | binary | nullable, encrypted | Base32 TOTP seed for TOTP-based MFA |
| `session_cookies` | binary | nullable, encrypted | Cached browser session (reduces full login frequency) |
| `status` | enum | NOT NULL, default: `active` | Values: `active`, `mfa_required`, `credential_error`, `error` |
| `last_synced_at` | utc_datetime | nullable | Timestamp of most recent successful sync |
| `sync_interval_hours` | integer | NOT NULL, default: 24 | How often to auto-sync (minimum 1) |
| `is_manual_only` | boolean | NOT NULL, default: false | True when no automated sync is configured |
| `inserted_at` | utc_datetime | NOT NULL | |
| `updated_at` | utc_datetime | NOT NULL | |

**Validation rules**:
- When `is_manual_only` is false, `credential_username` and `credential_password` MUST
  be present.
- When `sync_method: ofx_direct`, `ofx_direct_url` MUST be present.
- `sync_interval_hours` must be ≥ 1.
- `status` transitions:
  - `active` → `mfa_required` when scraper detects an MFA challenge it cannot auto-resolve
  - `active` → `credential_error` when login fails (wrong credentials)
  - `mfa_required` → `active` on successful MFA resolution and sync
  - `credential_error` → `active` on successful sync after credential update
  - Any → `error` on unexpected scraper failure

---

### Account

A specific financial account at an Institution, or a standalone manual account.

| Field | Type | Constraints | Notes |
|-------|------|-------------|-------|
| `id` | integer | PK, auto-increment | |
| `institution_id` | integer | FK → Institution, nullable | Null for pure manual accounts with no institution |
| `name` | string | NOT NULL | User-visible account name |
| `type` | enum | NOT NULL | Values: `checking`, `savings`, `brokerage`, `credit_card`, `loan`, `mortgage` |
| `balance` | decimal(15,4) | NOT NULL, default: 0 | Current balance |
| `currency` | string(3) | NOT NULL, default: `"USD"` | ISO 4217 |
| `external_account_id` | string | nullable | Account identifier from the institution's export (for dedup on re-sync) |
| `is_manual` | boolean | NOT NULL, default: false | True when user enters transactions by hand |
| `is_active` | boolean | NOT NULL, default: true | False when account is closed/removed |
| `inserted_at` | utc_datetime | NOT NULL | |
| `updated_at` | utc_datetime | NOT NULL | |

**Validation rules**:
- `is_manual` must be true when `institution_id` is null.
- `balance` sign convention: positive = asset balance; negative = amount owed
  (credit card, loan, mortgage).

**Derived field — net worth contribution**:
- Asset accounts (`checking`, `savings`, `brokerage`): add `balance` to assets.
- Liability accounts (`credit_card`, `loan`, `mortgage`): add `abs(balance)` to
  liabilities.

---

### Transaction

A single financial event against an Account.

| Field | Type | Constraints | Notes |
|-------|------|-------------|-------|
| `id` | integer | PK, auto-increment | |
| `account_id` | integer | FK → Account, NOT NULL | |
| `date` | date | NOT NULL | Posting date |
| `amount` | decimal(15,4) | NOT NULL | Positive = money in; Negative = money out |
| `merchant_name` | string | nullable | Cleaned/user-edited merchant name |
| `raw_merchant` | string | nullable | Original merchant string from OFX/CSV |
| `fit_id` | string | nullable | OFX `<FITID>` field — unique per institution for dedup |
| `notes` | string | nullable | User memo |
| `is_pending` | boolean | NOT NULL, default: false | True while transaction is unsettled |
| `is_split` | boolean | NOT NULL, default: false | True when split across categories |
| `is_manual` | boolean | NOT NULL, default: false | True when entered by user (no OFX source) |
| `category_id` | integer | FK → Category, nullable | Null when `is_split` is true |
| `inserted_at` | utc_datetime | NOT NULL | |
| `updated_at` | utc_datetime | NOT NULL | |

**Validation rules**:
- `amount` must be non-zero.
- When `is_split` is true, `category_id` MUST be null.
- When `is_split` is false, `category_id` MUST be set.
- `fit_id` + `account_id` is the dedup key for OFX imports (unique constraint).

**Dedup logic on import**: When parsing an OFX file, each `<STMTTRN>` has a `<FITID>`
(financial institution transaction ID). On import, upsert on `(account_id, fit_id)`.
If the row exists and is pending, update amount and clear `is_pending` if now settled.

---

### TransactionSplit

Breaks a single Transaction across multiple categories. Exists only when
`Transaction.is_split` is true.

| Field | Type | Constraints | Notes |
|-------|------|-------------|-------|
| `id` | integer | PK, auto-increment | |
| `transaction_id` | integer | FK → Transaction, NOT NULL | |
| `category_id` | integer | FK → Category, NOT NULL | |
| `amount` | decimal(15,4) | NOT NULL | Portion of the parent transaction |
| `notes` | string | nullable | Per-split memo |
| `inserted_at` | utc_datetime | NOT NULL | |
| `updated_at` | utc_datetime | NOT NULL | |

**Validation rules**:
- Sum of all split amounts MUST equal the parent `Transaction.amount`.
- Minimum 2 splits per split transaction.
- Each split `amount` must be non-zero and have the same sign as the parent.

---

### Category

Classification for transactions. System categories are seeded and cannot be deleted.

| Field | Type | Constraints | Notes |
|-------|------|-------------|-------|
| `id` | integer | PK, auto-increment | |
| `name` | string | NOT NULL, unique | e.g., "Groceries", "Dining", "Utilities" |
| `icon` | string | nullable | Emoji or icon identifier |
| `parent_id` | integer | FK → Category, nullable | One level deep only |
| `is_system` | boolean | NOT NULL, default: false | System categories cannot be deleted |
| `inserted_at` | utc_datetime | NOT NULL | |
| `updated_at` | utc_datetime | NOT NULL | |

**Seeded system categories**: Income, Housing, Food & Drink, Transport, Shopping,
Health, Entertainment, Utilities, Travel, Finance, Transfer, Uncategorized.

**Validation rules**:
- `name` is unique across all categories.
- `parent_id` must reference a top-level category (no more than one level of nesting).
- System categories may not be deleted.

---

### MerchantCategoryRule

Learned merchant-to-category mappings for auto-categorization.

| Field | Type | Constraints | Notes |
|-------|------|-------------|-------|
| `id` | integer | PK, auto-increment | |
| `merchant_pattern` | string | NOT NULL, unique | Lowercased, normalized merchant string |
| `category_id` | integer | FK → Category, NOT NULL | |
| `inserted_at` | utc_datetime | NOT NULL | |
| `updated_at` | utc_datetime | NOT NULL | |

**Auto-categorization logic**: On transaction import, normalize `raw_merchant` to a
lowercase pattern (strip punctuation, trailing digits like "#1234"). Look up in
`merchant_category_rules`. On match, assign that category. On miss, assign
"Uncategorized". When user overrides a category, upsert the merchant rule.

---

### Holding

An investment position within a brokerage Account.

| Field | Type | Constraints | Notes |
|-------|------|-------------|-------|
| `id` | integer | PK, auto-increment | |
| `account_id` | integer | FK → Account, NOT NULL | Must be a `brokerage` account |
| `symbol` | string | nullable | Ticker symbol; null for some asset types |
| `name` | string | NOT NULL | Security name |
| `quantity` | decimal(18,6) | NOT NULL | Number of shares/units |
| `cost_basis` | decimal(15,4) | nullable | Total cost basis in account currency |
| `current_price` | decimal(15,6) | nullable | Price per unit at last sync |
| `price_as_of` | utc_datetime | nullable | When `current_price` was last updated |
| `asset_class` | enum | NOT NULL | Values: `stock`, `etf`, `mutual_fund`, `bond`, `cash`, `other` |
| `external_security_id` | string | nullable | Institution's own security identifier (from OFX `<SECID>`) |
| `inserted_at` | utc_datetime | NOT NULL | |
| `updated_at` | utc_datetime | NOT NULL | |

**Derived fields** (computed, not stored):
- `current_value` = `quantity` × `current_price`
- `unrealized_gain_loss` = `current_value` − `cost_basis`
- `unrealized_gain_loss_pct` = `unrealized_gain_loss` / `cost_basis` × 100

**Sync behaviour**: Holdings are fully replaced on each sync for the account
(delete-then-insert from OFX `<INVPOSLIST>`).

---

### BudgetTarget

User-defined monthly spending limit for a Category.

| Field | Type | Constraints | Notes |
|-------|------|-------------|-------|
| `id` | integer | PK, auto-increment | |
| `category_id` | integer | FK → Category, NOT NULL | |
| `month` | integer | NOT NULL, 1–12 | |
| `year` | integer | NOT NULL | 4-digit year ≥ 2000 |
| `amount` | decimal(15,4) | NOT NULL | Monthly target (must be > 0) |
| `inserted_at` | utc_datetime | NOT NULL | |
| `updated_at` | utc_datetime | NOT NULL | |

**Unique constraint**: `(category_id, month, year)`.

---

### SyncLog

Audit trail for every sync attempt per Institution.

| Field | Type | Constraints | Notes |
|-------|------|-------------|-------|
| `id` | integer | PK, auto-increment | |
| `institution_id` | integer | FK → Institution, NOT NULL | |
| `status` | enum | NOT NULL | Values: `success`, `partial`, `mfa_required`, `error` |
| `accounts_updated` | integer | NOT NULL, default: 0 | |
| `transactions_added` | integer | NOT NULL, default: 0 | |
| `transactions_modified` | integer | NOT NULL, default: 0 | |
| `error_message` | string | nullable | Set when status is `error` or `partial` |
| `started_at` | utc_datetime | NOT NULL | |
| `completed_at` | utc_datetime | nullable | Null if sync is still in progress |
| `inserted_at` | utc_datetime | NOT NULL | |

---

## Migration Order

1. `categories`
2. `institutions`
3. `accounts` (FK → institutions)
4. `transactions` (FK → accounts, categories)
5. `transaction_splits` (FK → transactions, categories)
6. `merchant_category_rules` (FK → categories)
7. `holdings` (FK → accounts)
8. `budget_targets` (FK → categories)
9. `sync_logs` (FK → institutions)

## Index Strategy

| Table | Index | Purpose |
|-------|-------|---------|
| `transactions` | `(account_id, date DESC)` | Transaction feed per account |
| `transactions` | `(date DESC)` | Unified transaction feed |
| `transactions` | `(account_id, fit_id)` unique | OFX import dedup |
| `transactions` | `merchant_name` | Merchant search |
| `holdings` | `(account_id, symbol)` | Portfolio lookup |
| `budget_targets` | `(category_id, year, month)` unique | Budget lookup |
| `sync_logs` | `(institution_id, started_at DESC)` | Last sync status per institution |
| `merchant_category_rules` | `merchant_pattern` unique | Auto-categorization lookup |
