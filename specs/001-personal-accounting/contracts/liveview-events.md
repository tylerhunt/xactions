# Contract: LiveView Socket Events

**Type**: Phoenix LiveView client-server events
**Transport**: WebSocket (via Phoenix Channels)

These contracts define the events sent from the browser to the LiveView server
(`handle_event/3`) and the assigns that each LiveView exposes to its template.

---

## DashboardLive

**Route**: `GET /`

### Assigns

| Assign | Type | Description |
|--------|------|-------------|
| `net_worth` | `Decimal` | Total assets minus total liabilities |
| `total_assets` | `Decimal` | Sum of all asset account balances |
| `total_liabilities` | `Decimal` | Sum of all liability account balances (as positive number) |
| `net_worth_change` | `Decimal` | Month-over-month change in net worth |
| `accounts` | `[Account]` | All active accounts with current balances |
| `sync_status` | `map` | `%{institution_id => :idle \| :syncing \| :mfa_required \| :error}` |
| `attention_required` | `[Institution]` | Institutions needing credential update or MFA |

### Events (client → server)

| Event | Payload | Description |
|-------|---------|-------------|
| `"sync_now"` | `%{"institution_id" => id}` | Trigger manual sync for one institution |
| `"sync_all"` | `%{}` | Trigger manual sync for all active institutions |

### PubSub subscriptions

| Topic | Message | Effect |
|-------|---------|--------|
| `"sync:status"` | `{:sync_started, institution_id}` | Mark institution as `:syncing` |
| `"sync:status"` | `{:sync_complete, institution_id}` | Reload accounts; mark institution `:idle` |
| `"sync:status"` | `{:sync_error, institution_id, reason}` | Mark institution `:error` |
| `"sync:status"` | `{:mfa_required, institution_id}` | Mark institution `:mfa_required`; add to `attention_required` |

---

## AccountsLive

**Route**: `GET /accounts`

### Assigns

| Assign | Type | Description |
|--------|------|-------------|
| `institutions` | `[Institution]` | All institutions with their accounts nested |
| `changeset` | `Changeset \| nil` | Active form changeset |
| `modal` | `:add_institution \| :edit_credentials \| :add_manual_account \| :confirm_remove \| nil` | Active modal |

### Events (client → server)

| Event | Payload | Description |
|-------|---------|-------------|
| `"open_add_institution"` | `%{}` | Open the "Add Institution" form |
| `"save_institution"` | `%{"institution" => attrs}` | Create a new institution with credentials |
| `"open_edit_credentials"` | `%{"institution_id" => id}` | Open credential edit form for an institution |
| `"save_credentials"` | `%{"institution_id" => id, "username" => string, "password" => string}` | Update encrypted credentials |
| `"open_add_manual_account"` | `%{"institution_id" => id \| nil}` | Open add-manual-account form |
| `"save_manual_account"` | `%{"account" => attrs}` | Create a manual account |
| `"open_remove_institution"` | `%{"institution_id" => id}` | Open confirm-remove dialog |
| `"confirm_remove_institution"` | `%{"institution_id" => id}` | Remove institution and all its data |
| `"cancel"` | `%{}` | Close any open modal |

### Validation rules enforced server-side

- `save_institution`: `name` required; `scraper_module` must be a known module;
  `credential_username` and `credential_password` required (unless `is_manual_only`).
- `save_credentials`: both `username` and `password` must be non-empty strings.
- `save_manual_account`: `name` required; `type` must be valid enum value.

---

## TransactionsLive

**Route**: `GET /transactions`

### Assigns

| Assign | Type | Description |
|--------|------|-------------|
| `transactions` | `[Transaction]` | Current page of transactions (50 per page) |
| `total_count` | `integer` | Total matching transaction count |
| `filters` | `map` | Active filters: `account_id`, `category_id`, `date_from`, `date_to`, `query` |
| `categories` | `[Category]` | All categories for filter/edit dropdowns |
| `accounts` | `[Account]` | All accounts for filter dropdown |
| `editing_id` | `integer \| nil` | ID of transaction being category-edited inline |
| `split_transaction_id` | `integer \| nil` | ID of transaction open in split editor |
| `split_changeset` | `Changeset \| nil` | Active split form changeset |

### Events (client → server)

| Event | Payload | Description |
|-------|---------|-------------|
| `"filter_change"` | `%{"filters" => attrs}` | Update active filters; reloads list |
| `"search"` | `%{"query" => string}` | Merchant search; debounced 300ms client-side |
| `"edit_category"` | `%{"id" => txn_id, "category_id" => cat_id}` | Update category; upsert merchant rule |
| `"open_split"` | `%{"id" => txn_id}` | Open split editor |
| `"save_split"` | `%{"id" => txn_id, "splits" => [%{"category_id" => id, "amount" => string}]}` | Save transaction splits |
| `"cancel_split"` | `%{}` | Close split editor |
| `"add_manual_transaction"` | `%{"transaction" => attrs}` | Add transaction to a manual account |
| `"load_more"` | `%{}` | Append next page |

### Validation rules enforced server-side

- `save_split`: split amounts must sum exactly to parent amount; minimum 2 splits;
  each split needs a valid `category_id`.
- `add_manual_transaction`: `account_id` must be a manual account; `date`, `amount`,
  and `category_id` required.

---

## PortfolioLive

**Route**: `GET /portfolio`

### Assigns

| Assign | Type | Description |
|--------|------|-------------|
| `holdings` | `[Holding]` | All holdings with computed `current_value` and `gain_loss` |
| `total_value` | `Decimal` | Sum of all holding current values |
| `total_cost_basis` | `Decimal` | Sum of all cost bases |
| `total_gain_loss` | `Decimal` | Total unrealized gain/loss |
| `allocation` | `[%{class: atom, value: Decimal, pct: float}]` | Asset class breakdown |
| `period` | `:w1 \| :m1 \| :m3 \| :y1 \| :all` | Selected chart period |
| `price_as_of` | `DateTime \| nil` | Oldest price timestamp across all holdings |

### Events (client → server)

| Event | Payload | Description |
|-------|---------|-------------|
| `"set_period"` | `%{"period" => "w1" \| "m1" \| "m3" \| "y1" \| "all"}` | Change chart time period |

---

## ReportsLive

**Route**: `GET /reports`

### Assigns

| Assign | Type | Description |
|--------|------|-------------|
| `selected_month` | `Date` | First day of the reporting month |
| `spending_by_category` | `[%{category: Category, actual: Decimal, target: Decimal \| nil, on_pace: Decimal}]` | Monthly spend vs target |
| `comparison_month` | `Date` | Month being compared against (defaults to previous month) |
| `comparison_data` | `[%{category: Category, current: Decimal, previous: Decimal, change: Decimal, pct: float}]` | Month-over-month deltas |
| `net_worth_history` | `[%{month: Date, net_worth: Decimal}]` | Rolling 12-month net worth |
| `categories` | `[Category]` | All categories for budget target editing |

### Events (client → server)

| Event | Payload | Description |
|-------|---------|-------------|
| `"select_month"` | `%{"month" => "YYYY-MM"}` | Change reporting month |
| `"set_budget"` | `%{"category_id" => id, "amount" => string}` | Set/update monthly budget target |
| `"clear_budget"` | `%{"category_id" => id}` | Remove budget target for selected month |

### Validation rules enforced server-side

- `set_budget`: `amount` must parse to a positive decimal; `category_id` must be valid.
- `select_month`: must parse to a valid `YYYY-MM` date.

---

## MfaLive (Modal Component)

**Purpose**: Collects a one-time MFA code from the user when the sync scraper hits an
SMS/push-based MFA challenge it cannot resolve automatically.

### Assigns

| Assign | Type | Description |
|--------|------|-------------|
| `mfa_institution` | `Institution \| nil` | Institution waiting for MFA input; nil when not active |
| `mfa_code` | `string` | Current input value |

### Events (client → server)

| Event | Payload | Description |
|-------|---------|-------------|
| `"submit_mfa"` | `%{"institution_id" => id, "code" => string}` | Forward OTP code to the waiting SyncWorker |
| `"dismiss_mfa"` | `%{"institution_id" => id}` | Cancel the pending sync; mark institution `mfa_required` |

### PubSub subscriptions

| Topic | Message | Effect |
|-------|---------|--------|
| `"sync:status"` | `{:mfa_required, institution_id}` | Open MFA modal for that institution |
| `"sync:status"` | `{:mfa_resolved, institution_id}` | Close MFA modal |
