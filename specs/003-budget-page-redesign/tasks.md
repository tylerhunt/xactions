# Tasks: Budget Page Redesign

**Input**: Design documents from `specs/003-budget-page-redesign/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓, quickstart.md ✓

**TDD Note**: Per the constitution, all test tasks MUST be written and confirmed
failing (red) before the corresponding implementation tasks begin.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no file-conflict dependencies)
- **[Story]**: User story this task belongs to (US1–US5)

---

## Phase 1: Setup

**Purpose**: Verify environment is ready. No structural changes needed — the
project already exists and compiles.

- [ ] T001 Verify `mix test` passes on the current branch before any changes in shell
- [ ] T002 Run `mix ecto.migrate` to confirm migration baseline in shell

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Context API changes and DB migration that all user story phases
depend on. No user story work can begin until this phase is complete.

⚠️ CRITICAL: Complete in order — tests red → implementation green.

### Context functions (total_income, total_allocated, total_spent)

- [ ] T003 Write failing tests for `total_income/1`, `total_allocated/1`, and `total_spent/1` in `test/xactions/budgeting/budgeting_test.exs` — confirm red with `mix test test/xactions/budgeting/`
- [ ] T004 Promote `total_income/1` and `total_allocated/1` from private to public; add `total_spent/1` (sum per-envelope spending) in `lib/xactions/budgeting/budgeting.ex` — confirm T003 green

### Envelope color field

- [ ] T005 Write failing test for `color` auto-assignment from palette and hex format validation on envelope creation in `test/xactions/budgeting/budgeting_test.exs` — confirm red
- [ ] T006 [P] Create migration `priv/repo/migrations/TIMESTAMP_add_color_to_budget_envelopes.exs` — nullable `color :string` column
- [ ] T007 [P] Update `BudgetEnvelope.changeset/2` in `lib/xactions/budgeting/budget_envelope.ex` — cast `:color`, validate hex format (`~r/^#[0-9a-fA-F]{6}$/`), assign default palette color cyclically on insert
- [ ] T008 Run `mix ecto.migrate` in shell — confirm T005 green after migration

**Checkpoint**: `mix test test/xactions/budgeting/` — all green before continuing.

---

## Phase 3: User Story 1 — View Monthly Budget At a Glance (Priority: P1) 🎯 MVP

**Goal**: Four summary cards above the envelope list showing Monthly Income,
Allocated, Spent, and Unallocated for the current month. Unallocated is green
when ≥ 0, red when negative.

**Independent Test**: Load `/budget` with income transactions and envelopes;
verify four cards render the correct figures, and the unallocated card changes
color based on sign.

### Tests (write first — confirm red before T011)

- [ ] T009 Write failing LiveView tests for the four summary cards in `test/xactions_web/live/budget_live_test.exs`:
  - `[data-summary="income"]` shows correct income total
  - `[data-summary="allocated"]` shows correct allocated total
  - `[data-summary="spent"]` shows correct spent total
  - `[data-summary="unallocated"]` shows correct unallocated value
  - `[data-summary="unallocated"]` has red color class when negative
  - Remove the obsolete `[data-tbb]` test — confirm these new tests are red

### Implementation

- [ ] T010 Add `monthly_income`, `total_allocated`, `total_spent`, `unallocated` assigns to `load_budget_data/2` in `lib/xactions_web/live/budget_live.ex` (calls the newly public context functions)
- [ ] T011 [US1] Render four summary cards in `lib/xactions_web/live/budget_live.ex` using raw Tailwind (no DaisyUI):
  - Replace the `stats` / TBB block with four `bg-white border border-black/[.08] rounded-xl p-5` cards in a `grid grid-cols-1 md:grid-cols-4 gap-4` container
  - Each card: `data-summary` attribute, label (`text-sm text-[#717182]`), value (`text-3xl tracking-tight`)
  - Unallocated value: inline `style` for red (`#d4183d`) when negative, green (`#10b981`) when ≥ 0
  - Root container: `min-h-screen bg-[#f8f7f5]`

**Checkpoint**: `mix test test/xactions_web/live/budget_live_test.exs` — T009 green.

---

## Phase 4: User Story 2 — Navigate Between Months (Priority: P1)

**Goal**: Prev/next chevron buttons flank a month/year heading. Clicking
changes the displayed month; all figures (summary cards + envelopes) update.

**Independent Test**: Navigate to a prior month and verify the heading and
summary figures update; navigate forward to return to the current month.

### Tests (write first — confirm red before T014)

- [ ] T012 Write failing LiveView tests for month navigation in `test/xactions_web/live/budget_live_test.exs`:
  - Page renders a `[data-month-nav]` container with current month heading
  - `phx-click="prev_month"` changes heading to prior month
  - `phx-click="next_month"` from prior month returns to current month
  - Summary figures reload after navigation

### Implementation

- [ ] T013 [US2] Add `prev_month` and `next_month` event handlers in `lib/xactions_web/live/budget_live.ex` — use `Date.shift(date, month: ±1)` and reload budget data
- [ ] T014 [US2] Add month navigation UI to `lib/xactions_web/live/budget_live.ex`:
  - `data-month-nav` wrapper div
  - `phx-click="prev_month"` / `phx-click="next_month"` buttons with Heroicons chevron-left/right (`size-5`)
  - `h2` with `text-3xl tracking-tight` showing `month + " " + year`
  - Positioned above the summary cards

**Checkpoint**: `mix test test/xactions_web/live/budget_live_test.exs` — T012 green.

---

## Phase 5: User Story 3 — Envelope Budget Table + Inline Editing (Priority: P1)

**Goal**: Single table replacing per-envelope cards. Columns: color dot + name,
budgeted (click-to-edit), spent, balance (accounting format), progress bar.
Overspent rows show red balance and red progress bar.

**Independent Test**: Render the table with one within-budget and one overspent
envelope; verify all columns; click the budgeted amount, change the value,
confirm on Enter, and verify the updated value persists.

### Tests (write first — confirm red before T018)

- [ ] T015 Write failing LiveView tests for table rendering in `test/xactions_web/live/budget_live_test.exs`:
  - `[data-envelope-row="#{env.id}"]` element exists per active envelope
  - `[data-envelope-color]` dot is present with the envelope's color in inline style
  - `[data-budgeted]` cell shows correct formatted value
  - `[data-spent]` cell shows correct value
  - `[data-balance]` cell shows accounting-format value; red style when overspent
  - `[data-progress-bar]` element has correct `width` percentage in style
  - `[data-progress-bar]` is styled red when overspent
  - Remove obsolete `[data-envelope-id]` / `[data-form="allocation"]` tests
- [ ] T016 Write failing LiveView test for click-to-edit in `test/xactions_web/live/budget_live_test.exs`:
  - Click `[data-budgeted]` triggers `edit_envelope` event; input appears
  - Submit updated amount via `set_allocation`; `[data-budgeted]` shows new value
  - Press Escape or `cancel_edit` dismisses the input without saving

### Implementation

- [ ] T017 [US3] Add `editing_envelope_id` assign (default `nil`) and `edit_envelope`/`cancel_edit` event handlers in `lib/xactions_web/live/budget_live.ex`
- [ ] T018 [US3] Rewrite the envelope list section as a `<table>` in `lib/xactions_web/live/budget_live.ex`:
  - Container: `bg-white border border-black/[.08] rounded-xl overflow-hidden`
  - `<thead>`: Envelope, Budgeted, Spent, Balance, Progress — `text-sm text-[#717182]`
  - `<tbody>`: one `<tr data-envelope-row={env.id}>` per envelope:
    - Color dot: `w-3 h-3 rounded-full` with `style="background-color: #{env.color}"`, `data-envelope-color`
    - Budgeted cell: `data-budgeted` — shows value as button when not editing; shows form+input when `editing_envelope_id == env.id`
    - Spent cell: `data-spent`
    - Balance cell: `data-balance` — accounting format helper (`($X.XX)` for negative); inline red style when overspent
    - Progress bar: `data-progress-bar` inner div with `style="width: X%"`, `transition-[width] duration-500`, red color when overspent
  - Hover: `hover:bg-[#ececea]/30 transition-colors`
  - Keep `data-envelope-name` attribute on name cell for compatibility

**Checkpoint**: `mix test test/xactions_web/live/budget_live_test.exs` — T015, T016 green.

---

## Phase 6: User Story 4 — Consistent Visual Style Across All Pages (Priority: P2)

**Goal**: Sticky navbar with backdrop blur on all pages. Warm off-white
background and white card surfaces visible across the app.

**Independent Test**: Visit `/budget` and any other page; verify sticky navbar
is present and the page background matches the design palette.

### Tests (write first — confirm red before T021)

- [ ] T019 Write failing LiveView test for sticky navbar in `test/xactions_web/live/budget_live_test.exs`:
  - `[data-navbar]` element is rendered
  - `[data-navbar]` has class `sticky` (or verify the element exists with a `data-navbar` attribute)

### Implementation

- [ ] T020 [US4] Rewrite the `app/1` function navbar in `lib/xactions_web/components/layouts.ex` using raw Tailwind (no DaisyUI):
  - `<header data-navbar class="sticky top-0 z-10 border-b border-black/[.08] bg-white/80 backdrop-blur-sm">`
  - `max-w-7xl mx-auto px-6 py-4` inner wrapper
  - App name link: `text-xl tracking-tight text-[#030213]`
  - Nav links: `text-sm text-[#717182] hover:text-[#030213] transition-colors px-3 py-2 rounded-lg hover:bg-[#ececea]`
  - Active link: `bg-[#ececea] text-[#030213]`
  - User dropdown: retained, restyled with raw Tailwind
  - Mobile hamburger: retained, restyled with raw Tailwind
- [ ] T021 [US4] Confirm `bg-[#f8f7f5]` is on the root container in `lib/xactions_web/live/budget_live.ex` (should already be set from Phase 3)

**Checkpoint**: `mix test` — full suite green.

---

## Phase 7: User Story 5 — Create and Archive Envelopes (Priority: P2)

**Goal**: Create and archive envelopes from the budget page without leaving.
Form and controls use the new Tailwind design language.

**Independent Test**: Create a new envelope via the form; verify it appears
as a row in the table. Archive it; verify the row disappears.

### Tests (write first — confirm red before T024)

- [ ] T022 Update failing LiveView tests for create/archive in `test/xactions_web/live/budget_live_test.exs`:
  - `button[phx-click='open_create_envelope']` still triggers the form
  - `[data-form='create-envelope']` form is present after opening
  - After create, `[data-envelope-name='Utilities']` row appears in the table
  - Archive button on a row removes that row (update selector to `[data-envelope-row='#{env.id}'] [phx-click='archive_envelope']`)

### Implementation

- [ ] T023 [US5] Rewrite the create-envelope form in `lib/xactions_web/live/budget_live.ex` using raw Tailwind:
  - `bg-white border border-black/[.08] rounded-xl p-5 mb-6`
  - Name input: `border border-black/[.08] rounded-lg px-3 py-2 text-sm w-full`
  - Type select: same style
  - Submit / Cancel buttons: primary (`bg-[#030213] text-white rounded-lg px-4 py-2 text-sm`) and ghost (`hover:bg-[#ececea] rounded-lg px-4 py-2 text-sm`)
  - Preserve `data-form="create-envelope"` attribute
- [ ] T024 [US5] Rewrite the "New Envelope" button and archive button in `lib/xactions_web/live/budget_live.ex` using raw Tailwind:
  - New Envelope: `px-4 py-2 bg-[#ececea] hover:bg-[#ececea]/80 rounded-lg text-sm transition-colors`
  - Archive: `text-xs text-[#717182] hover:text-[#d4183d] transition-colors` inside the table row

**Checkpoint**: `mix test test/xactions_web/live/budget_live_test.exs` — T022 green.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [ ] T025 [P] Run `mix test` — confirm full suite green; fix any regressions
- [ ] T026 [P] Run `mix format` on all modified files
- [ ] T027 Verify `unassigned` spending section is preserved in BudgetLive and renders correctly with raw Tailwind styling (no DaisyUI card class)
- [ ] T028 Verify `format_decimal/1` helper is updated to use accounting format (e.g. `($45.00)` for negatives) rather than the old `$-45.00` style — update helper in `lib/xactions_web/live/budget_live.ex`
- [ ] T029 Manual smoke test: start server with `mix phx.server`, navigate to `/budget`, verify visual fidelity against the Figma design

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 — BLOCKS all user stories
- **Phase 3 (US1)**: Depends on Phase 2 (needs `total_income`, `total_allocated`, `total_spent`)
- **Phase 4 (US2)**: Depends on Phase 2; can run after or alongside Phase 3 (different assigns)
- **Phase 5 (US3)**: Depends on Phase 2 (needs `color` on envelopes); best after Phase 3 (table renders in same view)
- **Phase 6 (US4)**: Depends on Phase 3 (root container style already applied); layouts.ex change is independent
- **Phase 7 (US5)**: Depends on Phase 5 (create form lives inside the same rewritten render)
- **Phase 8 (Polish)**: Depends on all phases complete

### Within Each Phase

- Test tasks → confirm red → implementation tasks → confirm green
- Tasks marked [P] within a phase can run simultaneously (different files)

### Parallel Opportunities

Within Phase 2:
- T006 (migration file) and T007 (changeset) can run in parallel [P]

Within Phase 5:
- T015 and T016 (tests) can be written together before any implementation

---

## Parallel Execution Example: Phase 2

```
# Parallel: migration + changeset (after T005 test is written)
Task T006: Create color migration file
Task T007: Update BudgetEnvelope changeset
# Then T008: run migration
```

---

## Implementation Strategy

### MVP (US1 only — Phases 1–3)

1. Complete Phase 1: Verify baseline
2. Complete Phase 2: Foundational (color + context)
3. Complete Phase 3: Four summary cards
4. **STOP and validate**: Summary cards show correct live data

### Incremental Delivery

1. Phases 1–3 → Summary cards visible (US1 ✓)
2. Phase 4 → Month navigation (US2 ✓)
3. Phase 5 → Envelope table + inline editing (US3 ✓)
4. Phase 6 → Global style / sticky nav (US4 ✓)
5. Phase 7 → Create/archive envelopes (US5 ✓)
6. Phase 8 → Polish

---

## Notes

- TDD is mandatory per the constitution — never implement before the test is red
- DaisyUI classes must not appear in any new code; raw Tailwind only
- `data-*` attributes on test-facing elements must be preserved or updated in sync
  with the test changes in the same task
- All color values come from the Figma palette; use Tailwind arbitrary values
  (e.g. `bg-[#f8f7f5]`) except for runtime-dynamic colors which use inline `style`
