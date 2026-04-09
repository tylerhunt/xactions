# Feature Specification: Personal Accounting with Multi-Institution Sync

**Feature Branch**: `001-personal-accounting`
**Created**: 2026-04-09
**Status**: Draft
**Input**: User description: "Build a personal accounting application that syncs with the user's various bank accounts and investment institutions"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Connect Financial Accounts (Priority: P1)

A user opens the app for the first time and links their financial accounts. They search
for their bank or brokerage by name, authenticate with that institution, and within
moments see their account balances appear on a unified dashboard. From that point on,
the app automatically keeps those balances and transaction histories up to date.

**Why this priority**: The entire value of the application depends on account
connectivity. Without linked accounts, no other feature works. This is the entry point
for every new user.

**Independent Test**: A new user can search for an institution, complete the
authentication flow, and see at least one account balance on their dashboard — without
any other feature being present.

**Acceptance Scenarios**:

1. **Given** a new user with no linked accounts, **When** they search for their bank
   by name, **Then** they see their bank listed and can initiate connection.
2. **Given** a user initiating connection, **When** they successfully authenticate with
   the institution, **Then** at least one account appears on their dashboard with a
   current balance within 5 seconds.
3. **Given** a user with linked accounts, **When** the app syncs in the background,
   **Then** balances and new transactions are updated without any user action required.
4. **Given** a user whose sync credentials have expired, **When** the app detects the
   problem, **Then** the user receives a clear notification explaining which account
   needs reconnection and how to fix it.
5. **Given** a user who wants to remove an institution, **When** they disconnect it,
   **Then** all data from that institution is removed from their account.

---

### User Story 2 - View and Categorize Transactions (Priority: P2)

A user reviews their recent spending across all linked accounts in a single transaction
feed. They can filter by date range, account, or category. Transactions are
automatically assigned to categories (groceries, utilities, dining, etc.), and the
user can correct any miscategorization. Users can also split a single transaction
across multiple categories.

**Why this priority**: Transaction visibility and categorization are the core accounting
function of the app. Users need this to understand their spending and manage their
finances effectively.

**Independent Test**: A user with at least one linked account can view a unified
transaction list, apply a date filter, and change the category on a transaction — with
the change persisting across app restarts.

**Acceptance Scenarios**:

1. **Given** a user with multiple linked accounts, **When** they view the transaction
   feed, **Then** transactions from all accounts appear in reverse-chronological order
   with institution and account name visible on each entry.
2. **Given** a user viewing their transaction feed, **When** they apply a date range
   filter (e.g., current month), **Then** only transactions within that range are shown.
3. **Given** a transaction with an auto-assigned category, **When** the user changes
   the category, **Then** the new category is saved and future transactions from the
   same merchant default to the corrected category.
4. **Given** a large transaction the user wants to split, **When** they divide it across
   categories, **Then** the allocated portions must sum to the original transaction
   amount before the split can be saved.
5. **Given** a user searching for a specific transaction, **When** they type a merchant
   name or amount, **Then** matching transactions appear within 1 second.

---

### User Story 3 - Investment Portfolio Overview (Priority: P3)

A user views all their investment holdings in one place — across brokerages and
retirement accounts. They see current values, cost basis, and gain/loss for each
holding, plus an overall portfolio allocation breakdown. The app shows performance over
selectable time periods.

**Why this priority**: Investment accounts represent a significant portion of most
users' net worth. A personal accounting app that omits investments gives an incomplete
financial picture.

**Independent Test**: A user with at least one linked brokerage account can view a
list of their current holdings with current value and gain/loss displayed, without any
banking features being used.

**Acceptance Scenarios**:

1. **Given** a user with linked brokerage or retirement accounts, **When** they view
   the portfolio screen, **Then** each holding shows its name, current value, cost
   basis, and unrealized gain/loss in both dollar and percentage terms.
2. **Given** a portfolio view, **When** the user selects a time period (1 week,
   1 month, 3 months, 1 year, all time), **Then** a chart shows the portfolio's total
   value history for that period.
3. **Given** a user with holdings across multiple accounts, **When** they view
   allocation, **Then** a breakdown by asset class (stocks, bonds, cash, other) is
   shown as a percentage of total portfolio value.
4. **Given** market data is temporarily unavailable, **When** the user views the
   portfolio, **Then** last-known prices are displayed with a clearly visible
   "prices as of [date/time]" label.

---

### User Story 4 - Net Worth Dashboard and Spending Reports (Priority: P4)

A user sees their total net worth (assets minus liabilities) tracked over time. They
can view monthly spending reports broken down by category, compare spending
month-over-month, and set optional spending targets per category. The app highlights
categories where they are on pace to exceed their target.

**Why this priority**: Aggregate financial health metrics and trend analysis transform
raw account data into actionable insight — the primary reason users adopt a personal
accounting app.

**Independent Test**: A user with at least one bank account and one liability account
linked can view a net worth figure and a category breakdown of spending for the current
month — without investment features being used.

**Acceptance Scenarios**:

1. **Given** a user with linked accounts, **When** they view the dashboard, **Then**
   they see total assets, total liabilities, and net worth with month-over-month change
   clearly labeled.
2. **Given** a user viewing a monthly spending report, **When** they select a category,
   **Then** they see all transactions in that category for the selected month.
3. **Given** a user who has set a monthly spending target for a category, **When** they
   are on pace to exceed it within the current month, **Then** the category is flagged
   with the projected overage amount.
4. **Given** two consecutive months of transaction data, **When** the user views the
   month-over-month comparison, **Then** each spending category shows the dollar and
   percentage change between the two months.

---

### Edge Cases

- What happens when an institution is temporarily unavailable during a scheduled sync?
- How does the app handle a pending transaction that later settles with a different
  amount (e.g., a restaurant tip adjustment)?
- What happens if the user's institution is not in the supported list?
- How are foreign currency transactions displayed?
- What happens if a user's account is closed at an institution after it is linked?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Users MUST be able to search for and connect accounts from supported
  financial institutions using that institution's own authentication flow.
- **FR-002**: The app MUST automatically sync account balances and new transactions at
  least once every 24 hours without requiring user action.
- **FR-003**: Users MUST be able to manually trigger a sync at any time; updated data
  MUST appear within 30 seconds of the request completing.
- **FR-004**: Users MUST be able to view a unified transaction feed spanning all linked
  accounts, filterable by account, date range, and category.
- **FR-005**: The app MUST automatically categorize transactions based on merchant
  information.
- **FR-006**: Users MUST be able to override the category on any transaction; overrides
  MUST be applied to future transactions from the same merchant by default.
- **FR-007**: Users MUST be able to split a single transaction across multiple
  categories; split amounts MUST sum to the original transaction total.
- **FR-008**: Users MUST be able to search transactions by merchant name or amount.
- **FR-009**: Users MUST be able to view all investment holdings with current value,
  cost basis, and unrealized gain/loss.
- **FR-010**: The app MUST display a portfolio performance chart for selectable time
  periods: 1 week, 1 month, 3 months, 1 year, and all time.
- **FR-011**: The app MUST display asset allocation by class (stocks, bonds, cash,
  other) as a percentage of total portfolio value.
- **FR-012**: The app MUST display the user's net worth (total assets minus total
  liabilities) and track its change month-over-month.
- **FR-013**: The app MUST display monthly spending reports broken down by category.
- **FR-014**: Users MUST be able to compare spending between any two months by
  category.
- **FR-015**: Users MUST be able to set optional monthly spending targets per category;
  the app MUST alert the user when they are on pace to exceed a target.
- **FR-016**: Users MUST be notified when a linked account requires reconnection, with
  clear instructions to resolve the issue.
- **FR-017**: Users MUST be able to disconnect any linked institution; disconnection
  MUST remove all synced data for that institution from the app.
- **FR-018**: The app MUST support the following account types in v1: checking, savings,
  taxable brokerage, credit cards, personal loans, and mortgages. Retirement accounts
  (401k, IRA) and HSAs are explicitly deferred to a future version.
- **FR-019**: Each account MUST be either sync-linked (automatic) or manual (user-entered),
  never both simultaneously. Users MUST be able to create manual accounts and enter
  transactions by hand for institutions that cannot be synced (e.g., local credit
  unions, cash). Manual accounts and synced accounts MUST appear together throughout
  the app without distinction to the user.

### Key Entities

- **User**: The account holder who owns and manages the application.
- **Institution**: A financial institution (bank, brokerage, credit union) the user
  connects to.
- **Account**: A specific financial account at an institution (e.g., checking, savings,
  brokerage, retirement). Belongs to one Institution.
- **Transaction**: A single financial event (debit, credit, trade) recorded against an
  Account. Has a category, merchant, amount, and date.
- **Category**: A classification applied to transactions (e.g., Groceries, Dining,
  Utilities, Income). User-correctable per merchant.
- **Holding**: An investment position — a quantity of a security within an investment
  Account. Has cost basis and current market value.
- **Budget Target**: An optional user-defined monthly spending limit for a Category.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new user can connect their first financial account and see their balance
  on the dashboard within 3 minutes of first opening the app.
- **SC-002**: Account balances and transactions are refreshed at least once every 24
  hours automatically; users see fresh data within 30 seconds of a manual sync
  request.
- **SC-003**: At least 80% of transactions are auto-categorized correctly, measured by
  the rate at which users override the default category over a 30-day period.
- **SC-004**: Users can locate any specific transaction within their full history in
  under 30 seconds using search or filters.
- **SC-005**: The net worth dashboard and monthly spending report load completely within
  2 seconds on visits after the initial data sync.
- **SC-006**: Sync failures are surfaced to the user within 1 hour of occurrence with
  a clear, actionable message.
- **SC-007**: 85% of users surveyed after one week of use report that the app gives
  them a clear understanding of their overall financial position.

## Assumptions

- The app targets a single user (one person's finances); household or family sharing
  is out of scope for this version.
- Retirement accounts (401k, IRA) and HSAs are out of scope for v1 and are planned
  for a future release.
- All supported institutions provide a mechanism for automated account data access;
  the app does not use screen-scraping.
- Supported currencies in v1 are limited to the user's home currency; foreign currency
  transactions are displayed in their original currency with a disclosure that
  conversion is not supported.
- Historical transaction data is imported for the period the institution provides
  (typically the last 90 days); data prior to that window is not available on first
  connection.
- Investment price data may be delayed up to 15 minutes during market hours; this
  delay is disclosed to the user on the portfolio screen.
- The app is a personal finance viewer and tracker only; no money movement, bill
  payment, or transfers are in scope.
- Users have a stable internet connection; offline access to previously loaded data is
  desirable but not required for v1.
