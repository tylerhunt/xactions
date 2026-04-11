# Tasks: UI Redesign — Remove DaisyUI

**Input**: Design documents from `specs/004-ui-tailwind-redesign/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, contracts/ ✓, quickstart.md ✓

**TDD Note**: Per the constitution, all test tasks MUST be written and confirmed
failing (red) before the corresponding implementation tasks begin.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no file-conflict dependencies)
- **[Story]**: User story this task belongs to (US1–US5)

---

## Phase 1: Setup

**Purpose**: Verify environment and establish baseline before any changes.

- [X] T001 Verify `mix test` passes on the current branch (baseline green) in shell
- [X] T002 Audit DaisyUI class usage: run `grep -rn "btn\|card-body\|stat-title\|stat-value\|badge-\|alert-\|modal-box\|bg-base\|text-base\|text-error\|text-success" lib/xactions_web/` and save output as reference

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Restyle the three shared components used across multiple pages.
These have no dedicated test files — they are validated by the page-level tests
in Phases 3–7. Complete this phase before any page-level work.

- [X] T003 Restyle `lib/xactions_web/components/sync_status_badge.ex` — replace all `badge badge-*` classes with pill pattern: `text-xs font-medium px-2 py-0.5 rounded-full` + semantic `bg-[COLOR]/10 text-[COLOR]` per status (see research.md Decision 6)
- [X] T004 Restyle `lib/xactions_web/components/account_card.ex` — replace `hover:bg-base-200` with `hover:bg-[#ececea]/50`, `text-base-content/50` with `text-[#717182]`, `text-error` with `text-[#d4183d]`, `text-success` with `text-[#10b981]`
- [X] T005 Restyle `lib/xactions_web/components/core_components.ex` — update `flash/1` (remove `toast`, `alert`, `alert-info`, `alert-error` DaisyUI classes; use fixed-position toast container with left-border colored inner div per research.md Decision 5), `button/1` (remove `btn`, `btn-primary`, `btn-soft`; use primary/ghost Tailwind classes per research.md Decision 2), and `input/1` base classes (use `w-full border border-black/[.08] rounded-lg px-3 py-2 text-sm` per research.md Decision 4)

**Checkpoint**: All shared components updated. Begin page-level work.

---

## Phase 3: User Story 1 — Dashboard (Priority: P1) 🎯 MVP

**Goal**: Dashboard renders with readable text, no DaisyUI classes, net worth summary card, and consistent institution cards.

**Independent Test**: Load `/` while logged in; verify net worth card, institution list, sync/reconnect UI all render with the new design.

### Tests (write first — confirm red before T007)

- [X] T006 Write failing LiveView tests for dashboard restyling in `test/xactions_web/live/dashboard_live_test.exs`:
  - Add test: `[data-summary="net-worth"]` element is present
  - Add test: `[data-sync-all-btn]` element is present
  - Add test: rendered HTML does not contain `"stat-title"`, `"stat-value"`, `"btn-ghost"`, `"card-body"`, `"alert-error"`
  - Confirm these tests fail (red) — `mix test test/xactions_web/live/dashboard_live_test.exs`

### Implementation

- [X] T007 [US1] Restyle `lib/xactions_web/live/dashboard_live.ex`:
  - Add `data-summary="net-worth"` to net worth stat block; replace `stat`/`stat-title`/`stat-value` with summary card pattern: `bg-white border border-black/[.08] rounded-xl p-5`, label `text-sm text-[#717182] mb-1`, value `text-3xl tracking-tight`
  - Add `data-sync-all-btn` to Sync All button; replace `btn btn-ghost btn-sm` with ghost button pattern
  - Replace `card bg-base-100 border` / `card-body` institution containers with `bg-white border border-black/[.08] rounded-xl` / `p-4`
  - Replace `alert alert-error alert-sm` reconnect banner with `border-l-4 border-[#d4183d] bg-[#d4183d]/5 rounded-lg px-4 py-3 text-sm` (keep `data-reconnect-alert` attribute)
  - Replace `btn btn-ghost btn-xs` icon buttons with `p-1.5 rounded hover:bg-[#ececea] transition-colors text-[#717182] hover:text-[#030213]`
  - Set root container to `min-h-screen bg-[#f8f7f5]`
  - Confirm T006 tests are green: `mix test test/xactions_web/live/dashboard_live_test.exs`

**Checkpoint**: Dashboard fully restyled and all dashboard tests green.

---

## Phase 4: User Story 2 — Transactions (Priority: P1)

**Goal**: Transactions page renders without DaisyUI, with consistent card, button, input, and badge styles.

**Independent Test**: Load `/transactions`; verify the transaction list, add form, split badge, and inline edit all render with the new design.

### Tests (write first — confirm red before T009)

- [X] T008 Write failing LiveView tests for transactions restyling in `test/xactions_web/live/transactions_live_test.exs`:
  - Add test: `[data-add-transaction-form]` element appears after clicking add button
  - Add test: `[data-split-badge]` is present on a split transaction row
  - Add test: rendered HTML does not contain `"card-body"`, `"btn-primary"`, `"btn-ghost"`, `"badge-ghost"`, `"badge-xs"`
  - Confirm these tests fail (red) — `mix test test/xactions_web/live/transactions_live_test.exs`

### Implementation

- [X] T009 [US2] Restyle `lib/xactions_web/live/transactions_live.ex`:
  - Add `data-add-transaction-form` to the add-transaction form container
  - Add `data-split-badge` to the "split" badge span
  - Replace `card bg-base-100 border` / `card-body` with white panel pattern
  - Replace all `btn btn-primary btn-sm` with primary button pattern; all `btn btn-ghost btn-sm/btn-xs` with ghost button pattern
  - Replace `badge badge-ghost badge-xs` split indicator with pill: `text-xs font-medium px-2 py-0.5 rounded-full bg-[#717182]/10 text-[#717182]`
  - Ensure inline category-edit inputs use the standard input style
  - Confirm T008 tests are green: `mix test test/xactions_web/live/transactions_live_test.exs`

**Checkpoint**: Transactions page fully restyled and all transactions tests green.

---

## Phase 5: User Story 3 — Accounts (Priority: P2)

**Goal**: Accounts page renders without DaisyUI, institution cards and form match the budget page card style, error validation text is visible.

**Independent Test**: Load `/accounts`; verify institution cards, add-institution form, and error states all render with the new design.

### Tests (write first — confirm red before T011)

- [X] T010 Update failing LiveView tests for accounts restyling in `test/xactions_web/live/accounts_live_test.exs`:
  - Update the existing `".text-error"` selector (line ~54) to `"[data-field-error]"` or the raw Tailwind text color class to avoid coupling to DaisyUI class names
  - Add test: rendered HTML does not contain `"card-body"`, `"card-title"`, `"btn-primary"`, `"btn-ghost"`, `"alert-error"`
  - Confirm tests fail (red) — `mix test test/xactions_web/live/accounts_live_test.exs`

### Implementation

- [X] T011 [US3] Restyle `lib/xactions_web/live/accounts_live.ex`:
  - Replace `card bg-base-100 border` / `card-body` / `card-title` with white panel pattern; section headings use `font-medium text-[#030213]`
  - Replace `btn btn-primary btn-sm` with primary button; `btn btn-ghost btn-sm/btn-xs` with ghost/danger button patterns
  - Replace `alert alert-error alert-sm` reconnect banner with error left-border banner (keep `data-reconnect-alert` attribute)
  - Add `data-field-error` attribute to validation error elements (replacing `.text-error` coupling)
  - Confirm T010 tests are green: `mix test test/xactions_web/live/accounts_live_test.exs`

**Checkpoint**: Accounts page fully restyled and all accounts tests green.

---

## Phase 6: User Story 4 — Portfolio and Reports (Priority: P2)

**Goal**: Portfolio and reports pages render stat figures and controls without DaisyUI, using the summary card grid pattern.

**Independent Test**: Load `/portfolio` and `/reports`; verify summary cards, period toggle, and date form all render with the new design.

### Tests (write first — confirm red before T013 and T014)

- [X] T012 Write failing LiveView tests for portfolio and reports restyling:
  - In `test/xactions_web/live/portfolio_live_test.exs`: add tests for `[data-summary="total-value"]`, `[data-summary="cost-basis"]`, `[data-summary="gain-loss"]`, `[data-period-btn]`; assert rendered HTML does not contain `"stat-title"`, `"stat-value"`, `"btn-primary"`, `"btn-ghost"`
  - In `test/xactions_web/live/reports_live_test.exs`: add test for `[data-summary="net-worth"]`; assert rendered HTML does not contain `"stat-title"`, `"stat-value"`, `"btn-ghost"`
  - Confirm tests fail (red) — `mix test test/xactions_web/live/portfolio_live_test.exs test/xactions_web/live/reports_live_test.exs`

### Implementation

- [X] T013 [P] [US4] Restyle `lib/xactions_web/live/portfolio_live.ex`:
  - Replace `stat`/`stat-title`/`stat-value` blocks with summary card grid; add `data-summary="total-value"`, `data-summary="cost-basis"`, `data-summary="gain-loss"` attributes
  - Replace period toggle `btn btn-xs btn-primary / btn-ghost` with toggle pattern: active `px-3 py-1.5 rounded-lg text-sm bg-[#ececea] text-[#030213]`, inactive `px-3 py-1.5 rounded-lg text-sm text-[#717182] hover:bg-[#ececea]/50 transition-colors`; add `data-period-btn` to each
  - Replace `alert alert-warning` stale price banner with warning left-border banner (keep `data-price-stale` attribute)
  - Set root container to `min-h-screen bg-[#f8f7f5]`

- [X] T014 [P] [US4] Restyle `lib/xactions_web/live/reports_live.ex`:
  - Replace `stat`/`stat-title`/`stat-value` net worth block with summary card; add `data-summary="net-worth"` attribute
  - Replace `btn btn-sm btn-ghost` with ghost button pattern
  - Add `data-report-form` to the date range form
  - Set root container to `min-h-screen bg-[#f8f7f5]`
  - Confirm T012 tests are green: `mix test test/xactions_web/live/portfolio_live_test.exs test/xactions_web/live/reports_live_test.exs`

**Checkpoint**: Portfolio and reports pages fully restyled and their tests green.

---

## Phase 7: User Story 5 — Login and MFA (Priority: P2)

**Goal**: Login form and MFA prompt render without DaisyUI, using centered white card and consistent button styles.

**Independent Test**: Visit the login page while logged out; verify card, form, and button all render with the new design. Trigger MFA prompt and verify overlay renders.

### Tests (write first — confirm red before T016 and T017)

- [X] T015 Write failing LiveView tests for login and MFA restyling:
  - Create `test/xactions_web/live/login_live_test.exs`: test for `[data-login-card]` and `[data-login-form]`; assert rendered HTML does not contain `"card-body"`, `"bg-base-100"`, `"btn-primary"`, `"shadow-xl"`
  - Add MFA overlay test to `test/xactions_web/live/accounts_live_test.exs` or a new `mfa_live_test.exs`: verify `[data-mfa-overlay]` and `[data-mfa-form]` are present when MFA is triggered; assert no `"modal-box"`, `"modal-action"`, `"btn-primary"`, `"btn-ghost"`
  - Confirm tests fail (red)

### Implementation

- [X] T016 [P] [US5] Restyle `lib/xactions_web/live/auth/login_live.ex` and `lib/xactions_web/controllers/session_html/new.html.heex`:
  - Add `data-login-card` to the outer card container and `data-login-form` to the `<form>` element
  - Replace `card w-96 bg-base-100 shadow-xl` / `card-body` with `bg-white border border-black/[.08] rounded-xl p-8 w-full max-w-sm` (center with `flex min-h-screen items-center justify-center bg-[#f8f7f5]`)
  - Replace `btn btn-primary w-full` with primary button `w-full`
  - Ensure input fields use the standard input style

- [X] T017 [P] [US5] Restyle `lib/xactions_web/live/mfa_live.ex`:
  - Add `data-mfa-overlay` to the outer overlay container and `data-mfa-form` to the form
  - Replace `modal modal-open` / `modal-box` / `modal-action` with fixed overlay pattern: `fixed inset-0 bg-black/30 flex items-center justify-center z-50` outer, `bg-white border border-black/[.08] rounded-xl p-6 w-full max-w-md` inner card
  - Replace `btn btn-primary` / `btn btn-ghost` with primary / ghost button patterns
  - Confirm T015 tests are green

**Checkpoint**: Login and MFA screens restyled and their tests green.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [X] T018 [P] Run `mix test` — confirm full suite green; fix any regressions
- [X] T019 [P] Run `mix format` on all modified files
- [x] T020 Verify `bg-[#f8f7f5]` root container is applied consistently on all pages (dashboard, accounts, transactions, portfolio, reports)
- [x] T021 Manual smoke test: start server with `mix phx.server`, visit each page, confirm no invisible text or DaisyUI-specific styling artifacts

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 — shared components must be updated first since pages use them
- **Phase 3 (US1)**: Depends on Phase 2 (account_card + sync_status_badge used by dashboard)
- **Phase 4 (US2)**: Depends on Phase 2 (core_components inputs/buttons used in transactions form)
- **Phase 5 (US3)**: Depends on Phase 2 (account_card + sync_status_badge used by accounts)
- **Phase 6 (US4)**: Depends on Phase 2; independent of Phases 3–5
- **Phase 7 (US5)**: Depends on Phase 2; independent of Phases 3–6
- **Phase 8 (Polish)**: Depends on all phases complete

### Within Each Phase

- Test task → confirm red → implementation task → confirm green
- T013 and T014 [P] can run simultaneously (different files)
- T016 and T017 [P] can run simultaneously (different files)

### Parallel Opportunities

After Phase 2 completes:
- US4 (Portfolio/Reports) and US5 (Login/MFA) can be worked in parallel with US1–US3

---

## Parallel Execution Example: Phase 6

```
# T013 and T014 can run in parallel (different files):
Task T013: Restyle portfolio_live.ex
Task T014: Restyle reports_live.ex
```

---

## Implementation Strategy

### MVP (US1 + US2 — Phases 1–4)

1. Complete Phase 1: Verify baseline
2. Complete Phase 2: Shared components
3. Complete Phase 3: Dashboard (most visible)
4. Complete Phase 4: Transactions (most-used)
5. **STOP and validate**: Dashboard and Transactions are the highest-traffic pages — fixing these resolves the most visible contrast issues

### Incremental Delivery

1. Setup + Foundational → shared components consistent
2. Add US1 (Dashboard) → test + validate
3. Add US2 (Transactions) → test + validate
4. Add US3–US5 (remaining pages) → test + validate
5. Polish: full test suite + format + smoke test

---

## Notes

- [P] tasks = different files, no dependencies
- DaisyUI classes to eliminate: `btn`, `card`, `card-body`, `card-title`, `stat`, `stat-title`, `stat-value`, `badge-*`, `alert-*`, `modal`, `modal-box`, `modal-action`, `bg-base-100`, `text-base-content`, `text-error`, `text-success`
- Keep `data-*` attributes on all elements that existing tests target
- No backend changes — purely template/component styling
