# Feature Specification: UI Redesign — Remove DaisyUI, Apply Consistent Design System

**Feature Branch**: `004-ui-tailwind-redesign`
**Created**: 2026-04-10
**Status**: Draft
**Input**: "Rework the rest of the front end to use the design conventions established on the budget page. Remove the use of DaisyUI, preferring straight Tailwind classes instead. Ensure the text is readable—some text has a very low contrast ratio right now, since the background used to be dark."

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Dashboard Reads Clearly at a Glance (Priority: P1)

A user opens the dashboard and sees their net worth, account balances, and sync status without squinting. All text is legible against the warm off-white background. Cards and summary figures match the visual style of the budget page.

**Why this priority**: The dashboard is the landing page. Broken contrast here is the most visible regression from the background color change and the first thing users see.

**Independent Test**: Visit the dashboard while logged in; verify the net worth figure, each account card, and any alert or status messages are all readable (dark text on light background). Verify no DaisyUI component classes appear.

**Acceptance Scenarios**:

1. **Given** a logged-in user on the dashboard, **When** the page loads, **Then** all text has sufficient contrast against the page background with no invisible or near-invisible labels.
2. **Given** an institution that needs reconnection, **When** the reconnect alert is shown, **Then** it is visually distinct (colored border or background) and its text is fully legible.
3. **Given** the dashboard, **When** inspected, **Then** no DaisyUI class names (`btn`, `card`, `stat`, `alert`, `badge`, `modal`, etc.) appear in the rendered HTML.

---

### User Story 2 — Transactions Page Is Usable (Priority: P1)

A user browsing, filtering, or adding transactions sees a clean table layout consistent with the budget envelope table. Buttons, form inputs, and inline edit controls all use the new design language.

**Why this priority**: Transactions is the most-used page after the dashboard. Contrast and styling issues here directly impede daily use.

**Independent Test**: Visit `/transactions`; verify the transaction list, "Add Transaction" form, split-transaction controls, and filter inputs are all styled consistently and all text is readable.

**Acceptance Scenarios**:

1. **Given** a list of transactions, **When** the page loads, **Then** amounts, dates, and merchant names are all legible and the "split" badge is visible against its background.
2. **Given** the add-transaction form is open, **When** a user fills in fields, **Then** input labels and field text are clearly readable.
3. **Given** an inline category edit on a transaction row, **When** active, **Then** the input is styled consistently with the budget page inline edit.

---

### User Story 3 — Accounts Page Is Consistent (Priority: P2)

A user managing institutions and accounts sees cards, forms, and action buttons that match the budget page aesthetic. Adding or removing an institution uses the same form style as creating an envelope.

**Why this priority**: Less frequently visited than transactions, but the form and card styling is noticeably inconsistent after the budget page redesign.

**Independent Test**: Visit `/accounts`; verify institution cards, the "Add Institution" form, and action buttons all use the new design language.

**Acceptance Scenarios**:

1. **Given** one or more institutions, **When** the accounts page loads, **Then** each institution is displayed in a white rounded card with a subtle border, matching the budget card style.
2. **Given** the add-institution form is open, **When** a user views it, **Then** inputs and buttons match the create-envelope form on the budget page.

---

### User Story 4 — Portfolio and Reports Pages Are Readable (Priority: P2)

A user reviewing their investment portfolio or monthly reports sees summary statistics and charts with legible text and a consistent visual weight to the rest of the app.

**Why this priority**: These pages have DaisyUI stat classes that render poorly on the now-light background, but the actual interaction complexity is low.

**Independent Test**: Visit `/portfolio` and `/reports`; verify summary stat labels and values are readable, period toggle buttons are clearly active/inactive, and no DaisyUI classes remain.

**Acceptance Scenarios**:

1. **Given** the portfolio page, **When** it loads, **Then** "Total Value", "Cost Basis", and "Unrealized Gain/Loss" labels and values are all legible.
2. **Given** the period toggle on the portfolio page, **When** a period is selected, **Then** the active button is visually distinct from the inactive ones using the same active-state pattern as the navbar.

---

### User Story 5 — Login and MFA Screens Are Clean (Priority: P2)

A user logging in or completing MFA sees a centered form with readable labels and a primary action button that stands out clearly against the page background.

**Why this priority**: These screens are seen on every session start. The current DaisyUI card and modal are styled for a dark theme base and look out of place.

**Independent Test**: Visit the login page while logged out; verify the form card, input labels, and sign-in button are all styled consistently with the rest of the app.

**Acceptance Scenarios**:

1. **Given** the login page, **When** loaded, **Then** the form appears as a centered white card with a subtle border, matching the card style used throughout the app.
2. **Given** an MFA prompt, **When** displayed, **Then** it is rendered with readable text and action buttons styled consistently with the rest of the app.

---

### Edge Cases

- Pages with both a DaisyUI class and a conflicting Tailwind override: after this work no DaisyUI component classes should remain in the affected templates.
- Flash messages and error alerts must remain visible; they use colored borders or tinted backgrounds rather than relying on DaisyUI `alert` classes.
- Shared components (`core_components.ex`, `account_card.ex`, `sync_status_badge.ex`) must also be updated so style changes propagate consistently to every page that uses them.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: All pages (Dashboard, Accounts, Transactions, Portfolio, Reports, Login, MFA) MUST render without any DaisyUI component class names (`btn`, `card`, `card-body`, `card-title`, `stat`, `stat-title`, `stat-value`, `badge`, `alert`, `modal`, `modal-box`, `modal-action`).
- **FR-002**: All text on every page MUST have sufficient contrast against the warm off-white page background — body text uses near-black, muted labels use mid-grey.
- **FR-003**: Shared components (`account_card.ex`, `sync_status_badge.ex`, `core_components.ex`) MUST be updated to use raw Tailwind classes consistent with the budget page palette.
- **FR-004**: Primary action buttons MUST use the dark filled style used on the budget page. Secondary / ghost buttons MUST use the light hover style.
- **FR-005**: Form inputs MUST use the subtle-border rounded style from the budget create-envelope form.
- **FR-006**: Card / panel containers MUST use white background with subtle border and rounded corners, consistent with the budget envelope table.
- **FR-007**: Alert / reconnect banners MUST be visually distinct (e.g., colored left border or tinted background) without relying on DaisyUI `alert` classes.
- **FR-008**: The warm off-white page background MUST be applied consistently on every page.
- **FR-009**: All existing functionality (form submissions, phx-click events, inline edits, sync triggers) MUST continue to work after the restyling.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Zero DaisyUI component class names appear anywhere in the rendered HTML of any page.
- **SC-002**: All body text and label text achieves a contrast ratio of at least 4.5:1 against the page background (WCAG AA).
- **SC-003**: The full test suite continues to pass with 0 failures after all changes.
- **SC-004**: A visual review of every page confirms buttons, cards, inputs, and alerts are consistent with the budget page design.

## Assumptions

- The color palette from the budget page is canonical: near-black for body text, mid-grey for muted labels, a light warm-grey for hover/fill, subtle black-alpha for card borders, and white card surfaces on a warm off-white background.
- DaisyUI remains installed in the asset pipeline — only its component class names are removed from the affected templates.
- The flash/alert components in `core_components.ex` may retain their structural markup but must be restyled to not rely on DaisyUI alert tokens.
- The MFA screen is an inline LiveView overlay; it will be restyled in-place.
- Mobile responsiveness is maintained at existing breakpoints; no new responsive behavior is required.
- No changes to routing, authentication logic, or backend data fetching are in scope.
