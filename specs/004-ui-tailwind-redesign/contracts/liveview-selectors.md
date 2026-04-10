# LiveView Test Selectors: UI Redesign

These selectors define the test contract for each page. Tests must assert these
elements exist AND that their rendered HTML does not contain DaisyUI component
class names.

## Shared: No DaisyUI Classes

Every page test should include an assertion that the rendered HTML does not
contain DaisyUI component class names. The canonical list to check for:
`btn`, `card`, `card-body`, `stat`, `stat-value`, `badge`, `alert-info`,
`alert-error`, `alert-warning`, `modal`, `modal-box`.

## Dashboard (`/`)

| Selector | What it asserts |
|----------|----------------|
| `[data-summary="net-worth"]` | Net worth summary card is present |
| `[data-institution-card]` | At least one institution card renders |
| `[data-reconnect-alert]` | Reconnect alert exists when institution needs reconnection |
| `[data-sync-all-btn]` | Sync All button is present |

## Accounts (`/accounts`)

| Selector | What it asserts |
|----------|----------------|
| `[data-institution-card]` | Institution card renders per institution |
| `[data-add-institution-btn]` | Add Institution button is present |
| `[data-institution-form]` | Form appears when add institution is open |
| `[data-reconnect-alert]` | Reconnect alert shown for credential error institutions |

## Transactions (`/transactions`)

| Selector | What it asserts |
|----------|----------------|
| `[data-transaction-row]` | Transaction rows are present |
| `[data-split-badge]` | Split badge renders on split transactions |
| `[data-add-transaction-btn]` | Add Transaction button present |
| `[data-add-transaction-form]` | Form appears when add transaction is open |

## Portfolio (`/portfolio`)

| Selector | What it asserts |
|----------|----------------|
| `[data-summary="total-value"]` | Total value summary card is present |
| `[data-summary="cost-basis"]` | Cost basis summary card is present |
| `[data-summary="gain-loss"]` | Unrealized gain/loss summary card is present |
| `[data-period-btn]` | Period toggle buttons are present |
| `[data-price-stale]` | Stale price warning banner (when applicable) |

## Reports (`/reports`)

| Selector | What it asserts |
|----------|----------------|
| `[data-summary="net-worth"]` | Net worth summary card is present |
| `[data-report-form]` | Date range form is present |

## Login

| Selector | What it asserts |
|----------|----------------|
| `[data-login-card]` | Login card container is present |
| `[data-login-form]` | Login form is present |

## MFA

| Selector | What it asserts |
|----------|----------------|
| `[data-mfa-overlay]` | MFA overlay/dialog is present when prompted |
| `[data-mfa-form]` | MFA code input form is present |
