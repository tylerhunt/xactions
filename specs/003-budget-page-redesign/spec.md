# Feature Specification: Budget Page Redesign

**Feature Branch**: `003-budget-page-redesign`
**Created**: 2026-04-10
**Status**: Draft
**Input**: Use this design as the basis for the budget page:
https://www.figma.com/make/Dc1gifCFze6595F8BqCsgM. Update the rest of the
page layout to match the style.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Monthly Budget At a Glance (Priority: P1)

A user opens the budget page and immediately sees their full financial picture
for the month: how much income they have, how much is allocated across
envelopes, how much has been spent, and how much remains unallocated. The
overview is scannable without scrolling.

**Why this priority**: This is the primary value of the budget page. Everything
else builds on this summary.

**Independent Test**: Load the budget page and verify the four summary
numbers are visible and correct without any other features present.

**Acceptance Scenarios**:

1. **Given** a user has envelopes with allocations and recorded spending for
   the current month, **When** they navigate to the budget page, **Then** they
   see four summary figures — Monthly Income, Allocated, Spent, and Unallocated
   — each in its own card, prominently displayed above the envelope list.

2. **Given** the unallocated amount is negative (over-allocated), **When** the
   user views the summary, **Then** the unallocated figure is displayed in red
   to signal a problem.

3. **Given** the unallocated amount is zero or positive, **When** the user
   views the summary, **Then** the unallocated figure is displayed in green.

---

### User Story 2 - Navigate Between Months (Priority: P1)

A user can step backward and forward through months to review or plan their
budget. The month heading and all figures — summary cards, envelope
allocations, and spending — update to reflect the selected month.

**Why this priority**: Without month navigation the budget page only shows the
current month, making historical review and future planning impossible.

**Independent Test**: Navigate to a prior month and verify all figures update
to reflect that month's data.

**Acceptance Scenarios**:

1. **Given** the user is viewing the current month, **When** they click the
   previous-month button, **Then** the month heading changes and all figures
   reload for the prior month.

2. **Given** the user has navigated back several months, **When** they click
   the next-month button repeatedly, **Then** they can return to the current
   month and figures are correct.

---

### User Story 3 - View and Edit Envelope Budgets in a Table (Priority: P1)

All envelopes are shown in a single table (replacing the current card-per-
envelope layout). Each row shows the envelope name with its color indicator,
the budgeted amount (editable inline), amount spent, balance remaining (in
accounting format), and a visual progress bar. Overspent envelopes are
highlighted in red.

**Why this priority**: The table layout is the central redesign element — it
makes the full picture scannable and collapses several clicks into one view.

**Independent Test**: Render the envelope table with at least two envelopes —
one overspent — and verify all columns display correctly and inline editing
works.

**Acceptance Scenarios**:

1. **Given** multiple envelopes exist, **When** the user views the budget page,
   **Then** all active envelopes appear as rows in a single table with columns:
   name (with color indicator), budgeted, spent, balance, and progress.

2. **Given** an envelope is overspent, **When** the user views that row,
   **Then** the balance column shows the deficit in red in accounting format
   (e.g. `($45.00)`) and the progress bar is red.

3. **Given** a user clicks the budgeted amount on an envelope row, **When**
   they type a new value and confirm (Enter or click away), **Then** the
   allocation is saved and the row updates without a full page reload.

4. **Given** an envelope has zero budget and zero spending, **When** the user
   views the row, **Then** the progress bar is empty (not shown or shown at 0%)
   and balance shows $0.00.

---

### User Story 4 - Consistent Visual Style Across All Pages (Priority: P2)

The global app layout — background color, navigation bar, card surfaces, and
typography — is updated to match the visual language established in the budget
page design. All pages use the same warm neutral background, white card
surfaces, subtle borders, and clean typography.

**Why this priority**: Design consistency reduces cognitive load across the
app. The budget page redesign sets the new baseline.

**Independent Test**: Visit the dashboard, accounts, transactions, and reports
pages and verify the background, card, and typography styles are consistent
with the budget page.

**Acceptance Scenarios**:

1. **Given** the design system is applied, **When** a user visits any page in
   the app, **Then** the background is a warm off-white, content cards are
   white with subtle borders, and number typography uses tight tracking.

2. **Given** the navigation bar is updated, **When** a user views any page,
   **Then** the top bar has a semi-transparent white background that blurs
   content scrolling behind it, and remains visible when scrolling down.

---

### User Story 5 - Create and Archive Envelopes (Priority: P2)

Users can create a new envelope and archive an existing one without leaving
the budget page. These actions are accessible but do not dominate the layout.

**Why this priority**: Envelope management is less frequent than viewing and
editing — it should be available but not in the way.

**Independent Test**: Create a new envelope from the budget page, verify it
appears in the table, then archive it and verify it disappears.

**Acceptance Scenarios**:

1. **Given** the user needs a new envelope, **When** they initiate envelope
   creation and submit a name and type, **Then** the new envelope appears in
   the table for the current month.

2. **Given** an envelope is no longer needed, **When** the user archives it,
   **Then** the row is removed from the table and historical data is preserved.

---

### Edge Cases

- What happens when there are no envelopes? Show an empty state with a prompt
  to create the first envelope.
- What happens when income is not configured? The "Monthly Income" card should
  show $0 or "—" and the unallocated figure should reflect $0 income.
- What happens when a user enters a non-numeric value into the budget input?
  Revert to the previous value and show an inline error or flash message.
- What happens on narrow screens? The table must remain usable — either via
  horizontal scroll or a collapsed view.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The budget page MUST display a month navigation control allowing
  users to move to the previous or next month.
- **FR-002**: The budget page MUST display four summary figures above the
  envelope table: Monthly Income, Allocated, Spent, and Unallocated.
- **FR-003**: The unallocated figure MUST be displayed in red when negative and
  green when zero or positive.
- **FR-004**: Envelopes MUST be displayed in a single table with columns for
  name (with per-envelope color indicator), budgeted amount, spent amount,
  remaining balance, and a progress bar.
- **FR-005**: The remaining balance MUST be formatted in accounting style:
  negative values shown as `($X.XX)` in red, positive values as `$X.XX`.
- **FR-006**: Users MUST be able to edit the budgeted amount for an envelope
  inline by clicking the value in the table.
- **FR-007**: The progress bar for each envelope MUST turn red when spending
  exceeds the budgeted amount.
- **FR-008**: The global app layout MUST use a warm off-white background,
  white card surfaces, and subtle low-opacity borders across all pages.
- **FR-009**: The top navigation bar MUST be sticky (remains visible on scroll)
  with a semi-transparent, blurred background.
- **FR-010**: Each envelope MUST have a color indicator (colored dot) displayed
  in the table row.
- **FR-011**: Users MUST be able to create new envelopes and archive existing
  ones from the budget page.
- **FR-012**: When no envelopes exist, the page MUST display an empty state
  with a call to action to create an envelope.

### Key Entities

- **Envelope**: A named budget category with a color indicator, per-month
  allocation, cumulative spending for the month, and a computed remaining
  balance.
- **Monthly Summary**: Derived figures for a given month: total income, total
  allocated, total spent, and unallocated remainder.
- **Budget Period**: A month/year pair that scopes all figures on the page.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can read all envelope budget figures for the current month
  without scrolling on a standard desktop viewport.
- **SC-002**: Switching between months takes under 500ms to display updated
  figures (perceived as instant).
- **SC-003**: Inline budget editing completes — from click to saved value
  visible — in under one second without a full page reload.
- **SC-004**: The visual style is consistent across all six pages of the app
  (Dashboard, Accounts, Transactions, Portfolio, Budget, Reports), with no
  page using the old DaisyUI card-per-envelope or stark-white background style.
- **SC-005**: Overspent envelopes are immediately visually distinct from
  within-budget envelopes without requiring any user action.

## Assumptions

- Each envelope has a single user-assigned color that persists across months.
  If the data model does not currently store a color, a default palette will
  be assigned sequentially.
- Monthly Income is sourced from the existing "To Be Budgeted" context — the
  redesign surfaces this figure more prominently but does not change how it is
  calculated.
- The design applies to the authenticated app layout only; the login/MFA pages
  are out of scope.
- Dark mode is out of scope for this redesign iteration; the warm off-white
  light theme is the target.
- The existing `Budgeting` context module and database schema are not changed
  by this feature — only the presentation layer is updated.
- The `TransactionFeed` component shown in the Figma Make prototype is out of
  scope for the budget page; transactions are already accessible via the
  dedicated Transactions page.
