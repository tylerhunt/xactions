# Feature Specification: Personal Accounting with Multi-Institution Sync

**Feature Branch**: `001-personal-accounting`
**Created**: 2026-04-09
**Status**: Draft
**Input**: User description: "Build a personal accounting application that syncs with the user's various bank accounts and investment institutions"

## Clarifications

### Session 2026-04-09

- Q: How should the budgeting model work — simple per-category monthly targets, or a zero-based envelope system? → A: Zero-based budgeting with typed envelopes (fixed/variable/rollover); each envelope maps to one or more categories; income must be fully allocated each month.
- Q: For variable envelopes at month rollover, should the pre-filled default use the previous month's budgeted amount or actual spent amount? → A: Previous month's budgeted amount (reflects the user's intention, not variance).
- Q: How is the monthly income target established for zero-based allocation — manually entered, auto-derived, or real-money-in-hand? → A: YNAB model — no income target; "To Be Budgeted" equals actual Income-category transactions received minus envelope allocations; the pool grows as real income arrives.
- Q: Should rollover envelopes have a maximum accumulation cap? → A: Optional user-defined cap; when the accumulated balance reaches the cap, surplus rolls back into TBB instead of the envelope.

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

### User Story 4 - Zero-Based Budget Management (Priority: P4)

A user practices zero-based budgeting using a real-money-in-hand model (YNAB-style):
the app budgets only dollars that have actually arrived, not projected income. When
income transactions are recorded, they flow into a "To Be Budgeted" (TBB) pool. The
user creates envelopes (e.g., "Rent", "Groceries", "Car Repair"), assigns one or more
spending categories to each, and allocates dollars from TBB into envelopes. TBB must
reach exactly $0 for the month to be considered fully budgeted. Spending in each
category automatically draws down the matching envelope in real time as transactions
arrive. There is no separately-entered income target — TBB is computed from actual
Income-category transactions received minus the total already allocated to envelopes.

Envelopes have three types:
- **Fixed**: same dollar amount every month (rent, subscriptions); the app carries the
  amount forward automatically at month rollover.
- **Variable**: amount set fresh each month (groceries, dining); the app pre-fills the
  previous month's amount as a starting suggestion.
- **Rollover**: unspent balance accumulates across months (car repair fund, vacation
  savings); the balance carried forward adds to the next month's budget for that
  envelope.

**Why this priority**: Budgeting is the primary reason users adopt personal finance
software. Zero-based budgeting makes the "every dollar has a job" discipline explicit
and enforceable by the app rather than a mental exercise.

**Independent Test**: A user with no linked accounts can add a manual Income-category
transaction, create two envelopes with categories assigned, allocate the income to
those envelopes until TBB reaches $0, and see spending immediately reduce the
appropriate envelope balance when a manual spending transaction is added.

**Acceptance Scenarios**:

1. **Given** a user setting up their budget, **When** they create a "Rent" fixed
   envelope and assign the "Housing" category to it, **Then** the envelope appears in
   the budget view and all Housing transactions count against it.
2. **Given** a user who has received $3,000 in Income-category transactions but has
   only allocated $2,000 across envelopes, **When** they view the budget screen,
   **Then** "To Be Budgeted: $1,000.00" is prominently displayed; it reaches $0 only
   when all received income is allocated to envelopes.
3. **Given** a user with an active budget, **When** a transaction is imported that
   belongs to a category assigned to an envelope, **Then** the envelope's remaining
   balance decreases in real time without any user action.
4. **Given** a rollover envelope with $50 unspent from the previous month and no cap
   set, **When** the new month begins, **Then** the $50 carries forward and adds to
   that envelope's budget for the new month (cumulative balance).
4a. **Given** a rollover envelope with a $200 cap and a current accumulated balance of
    $180, **When** the month closes with $40 unspent, **Then** $20 rolls into the
    envelope (bringing it to the $200 cap) and the remaining $20 flows back into TBB.
5. **Given** a transaction whose category is not assigned to any active envelope,
   **When** the user views the budget screen, **Then** it appears in an "Unassigned
   Spending" section, surfacing gaps in the budget structure.
6. **Given** a user who wants to retire an envelope, **When** they archive it, **Then**
   the envelope no longer appears in the active budget allocation view but all its
   historical spending data remains intact in reports.
7. **Given** a month transition occurs, **When** the new month's budget is initialized,
   **Then** fixed and rollover envelopes carry their amounts forward automatically;
   variable envelopes are pre-filled with the previous month's budgeted amount as a
   starting point.

---

### User Story 5 - Net Worth Dashboard and Spending Reports (Priority: P5)

A user sees their total net worth (assets minus liabilities) tracked over time. They
can view monthly spending reports broken down by envelope and by category, and compare
spending month-over-month. The budget history grid shows each month's envelope
performance across the full history.

**Why this priority**: Trend data and aggregate net worth turn individual transactions
into a long-term financial picture. This is the "outcome" view that motivates continued
engagement with the budgeting workflow.

**Independent Test**: A user with at least one bank account and one liability account
linked can view a net worth figure and a monthly envelope spending summary — without
investment features being used.

**Acceptance Scenarios**:

1. **Given** a user with linked accounts, **When** they view the dashboard, **Then**
   they see total assets, total liabilities, and net worth with month-over-month change
   clearly labeled.
2. **Given** a user viewing a monthly spending report, **When** they select an envelope,
   **Then** they see all transactions in categories belonging to that envelope for the
   selected month.
3. **Given** two consecutive months of data, **When** the user views the month-over-
   month comparison, **Then** each envelope shows the dollar and percentage change
   between months.
4. **Given** a user viewing the budget history grid, **When** they click a cell
   (month × envelope), **Then** they see the transactions that drove that month's
   spending for that envelope.

---

### Edge Cases

- What happens when an institution is temporarily unavailable during a scheduled sync?
- How does the app handle a pending transaction that later settles with a different
  amount (e.g., a restaurant tip adjustment)?
- What happens if the user's institution is not in the supported list?
- How are foreign currency transactions displayed?
- What happens if a user's account is closed at an institution after it is linked?
- What happens if spending in an envelope exceeds its monthly budget? (The envelope
  goes negative; the overage is shown clearly but does not block further spending.)
- What happens to a category's transactions if its envelope is archived mid-month?
  (Transactions before archival remain attributed; the category moves to "Unassigned
  Spending" from the archival date forward.)

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
- **FR-013**: The app MUST display monthly spending reports broken down by envelope and
  by category.
- **FR-014**: Users MUST be able to compare spending between any two months by envelope.
- **FR-015**: Users MUST be able to create named budget envelopes with one of three
  types: fixed, variable, or rollover. Each envelope MUST be assignable to one or more
  spending categories.
- **FR-016**: The app MUST display a "To Be Budgeted" (TBB) balance computed as: the
  sum of all Income-category transactions received in the current month, minus the sum
  of all envelope allocations made for that month. TBB MUST be prominently visible on
  the budget screen at all times and update in real time as income transactions arrive
  or envelope allocations change. There is no manually-entered income target field.
- **FR-017**: A month's budget MUST be considered fully allocated only when TBB equals
  exactly $0. The app MUST visually distinguish fully allocated months (TBB = $0) from
  partially allocated months (TBB > $0) and over-allocated months (TBB < $0).
- **FR-018**: Spending transactions MUST automatically reduce the balance of the
  matching envelope in real time as transactions arrive (no manual envelope update
  required).
- **FR-019**: Transactions whose category is not assigned to any active envelope MUST
  appear in a dedicated "Unassigned Spending" view on the budget screen.
- **FR-020**: At month rollover, the app MUST automatically initialize the new month's
  budget with the following behavior per envelope type:
  - **Fixed**: carry forward the same budgeted amount as the previous month.
  - **Variable**: pre-fill the previous month's budgeted amount as a default starting
    point; the user MUST be able to change it before allocating.
  - **Rollover**: carry forward the previous month's budgeted amount plus any unspent
    balance (cumulative). If the envelope has an optional user-defined cap and the
    carried-forward balance would exceed it, the surplus MUST flow back into TBB rather
    than into the envelope.
- **FR-021**: Users MUST be able to archive an envelope. Archived envelopes MUST be
  excluded from the active budget allocation view and from month rollover calculations.
  All historical spending data for archived envelopes MUST remain accessible in reports.
  Hard-deletion of an envelope MUST only be permitted if it has no associated historical
  budget months.
- **FR-022**: Income available for allocation is always the real sum of transactions
  categorized under the top-level "Income" category for the current month. The app MUST
  update TBB automatically whenever an Income-category transaction is added, modified,
  or removed. No separate income target field exists.
- **FR-023**: The app MUST display a budget history grid (months × envelopes) allowing
  the user to click any cell to view the transactions behind that month's envelope
  spending.
- **FR-024**: Users MUST be notified when a linked account requires reconnection, with
  clear instructions to resolve the issue.
- **FR-025**: Users MUST be able to disconnect any linked institution; disconnection
  MUST remove all synced data for that institution from the app.
- **FR-026**: The app MUST support the following account types in v1: checking, savings,
  taxable brokerage, credit cards, personal loans, and mortgages. Retirement accounts
  (401k, IRA) and HSAs are explicitly deferred to a future version.
- **FR-027**: Each account MUST be either sync-linked (automatic) or manual
  (user-entered), never both simultaneously. Users MUST be able to create manual
  accounts and enter transactions by hand for institutions that cannot be synced.
  Manual accounts and synced accounts MUST appear together throughout the app without
  distinction to the user.

### Key Entities

- **User**: The account holder who owns and manages the application.
- **Institution**: A financial institution (bank, brokerage, credit union) the user
  connects to.
- **Account**: A specific financial account at an institution (e.g., checking, savings,
  brokerage). Belongs to one Institution.
- **Transaction**: A single financial event (debit, credit, trade) recorded against an
  Account. Has a category, merchant, amount, and date.
- **Category**: A classification applied to transactions (e.g., Groceries, Dining,
  Utilities, Income). User-correctable per merchant.
- **Holding**: An investment position — a quantity of a security within an investment
  Account. Has cost basis and current market value.
- **Budget Envelope**: A named bucket that groups one or more Categories for budgeting
  purposes. Has a type: fixed, variable, or rollover. Rollover envelopes MAY have an
  optional cap — a maximum accumulated balance beyond which surplus flows back to TBB.
  Can be archived (soft-deleted); archived envelopes are excluded from active budgeting
  but history is preserved.
- **Budget Month**: A record of a specific envelope's allocated amount for a specific
  calendar month. One Budget Month record per envelope per month. The "To Be Budgeted"
  balance is computed at query time as: sum of Income-category transactions for the
  month minus sum of all Budget Month allocation amounts for that month.
- **Envelope Category**: The many-to-many association between Budget Envelopes and
  Categories. A single category MUST belong to at most one active envelope at a time.

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
- **SC-008**: A user can create a complete zero-based budget for a month (all envelopes
  set, unallocated reaches $0) within 10 minutes of first setting up the envelope
  structure.

## Assumptions

- The app targets a single user (one person's finances); household or family sharing
  is out of scope for this version.
- Retirement accounts (401k, IRA) and HSAs are out of scope for v1 and are planned
  for a future release.
- Bank sync is performed by headless browser automation downloading OFX/CSV exports;
  the app does not rely on third-party financial aggregator APIs.
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
- A category MUST belong to at most one active envelope at a time; the same category
  cannot simultaneously draw from two envelopes.
- An envelope going over budget (negative remaining balance) is allowed; it is surfaced
  visually but does not block transaction recording.
