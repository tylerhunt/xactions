# Tasks: Envelope Category Association

**Input**: Design documents from `/specs/005-envelope-categories/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅

**Tests**: Included — TDD is mandatory per the project constitution (Principle II).
Write each test task first, confirm it **fails**, then implement.

**Organization**: Tasks are grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no blocking dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2)

---

## Phase 1: Setup

**Purpose**: Confirm the foundation — no migration needed, test helpers in place.

- [X] T001 Verify `envelope_categories` migration is applied and `Budgeting.assign_category/2` + `unassign_category/2` exist in `lib/xactions/budgeting/budgeting.ex`
- [X] T002 Confirm `Transactions.list_categories/0` returns all categories and is already called in `BudgetLive.load_budget_data/2` in `lib/xactions_web/live/budget_live.ex`

**Checkpoint**: No migration or dependency changes needed — proceed to foundational phase.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared helper used by both user stories — the category availability query.

**⚠️ CRITICAL**: Both user story phases depend on this.

- [X] T003 Write failing test for `Budgeting.list_available_categories/1` in `test/xactions/budgeting_test.exs`: given an optional `except_envelope_id`, returns categories not assigned to any other active envelope
- [X] T004 Implement `Budgeting.list_available_categories/1` in `lib/xactions/budgeting/budgeting.ex`: query `categories` excluding those in `envelope_categories` joined to non-archived envelopes, with optional `except_envelope_id` param to include the target envelope's own categories

**Checkpoint**: `mix test test/xactions/budgeting_test.exs` passes for T003/T004.

---

## Phase 3: User Story 1 — Create Envelope with Categories (Priority: P1) 🎯 MVP

**Goal**: Users can create an envelope and associate one or more categories in a single form submission.

**Independent Test**: Open the app, click "New Envelope", select ≥ 1 category, submit — envelope appears in table with categories stored. Attempt to submit with zero categories — form rejects it with a validation message.

### Tests for User Story 1

> **Write these FIRST. Confirm they FAIL before implementing.**

- [X] T005 [P] [US1] Write failing integration test for `Budgeting.create_envelope_with_categories/2` in `test/xactions/budgeting_test.exs`: success case creates envelope + join rows; empty category_ids returns error; duplicate category already on another envelope returns error
- [X] T006 [P] [US1] Write failing LiveView test for create flow in `test/xactions_web/live/budget_live_test.exs`: form renders category checkboxes; submitting with ≥ 1 category creates envelope; submitting with zero categories shows error flash

### Implementation for User Story 1

- [X] T007 [US1] Implement `Budgeting.create_envelope_with_categories(attrs, category_ids)` in `lib/xactions/budgeting/budgeting.ex`: wrap `create_envelope/1` + multiple `assign_category/2` calls in `Repo.transaction/1`; return `{:ok, envelope}` or `{:error, reason}` (depends on T003/T004)
- [X] T008 [US1] Add `:show_create_form` assigns wiring in `BudgetLive.mount/3` in `lib/xactions_web/live/budget_live.ex`: load `available_categories` via `Budgeting.list_available_categories()` and assign to socket
- [X] T009 [US1] Update `create_envelope` event handler in `lib/xactions_web/live/budget_live.ex`: extract `category_ids` from params, validate non-empty (flash error if empty), call `create_envelope_with_categories/2`
- [X] T010 [US1] Update create envelope form template in `lib/xactions_web/live/budget_live.ex`: add a scrollable checkbox list of `@available_categories` below the Type field; each checkbox uses `name="envelope[category_ids][]"` and `value={cat.id}`

**Checkpoint**: `mix test test/xactions/budgeting_test.exs` and `mix test test/xactions_web/live/budget_live_test.exs` pass for US1 tasks. Create form works end-to-end in the browser.

---

## Phase 4: User Story 2 — Edit Envelope via Dropdown Menu (Priority: P2)

**Goal**: A ChevronDown dropdown trigger next to each envelope name opens a menu with "Edit" and "Archive" items; selecting "Edit" opens an inline edit form for name and categories.

**Independent Test**: In the Envelopes table, click the `⌄` button next to any envelope name — dropdown appears with "Edit" and "Archive". Click "Edit" — form opens pre-populated with current name and categories. Change values and save — table updates. Attempt to remove all categories and save — error flash shown, envelope unchanged.

### Tests for User Story 2

> **Write these FIRST. Confirm they FAIL before implementing.**

- [X] T011 [P] [US2] Write failing integration test for `Budgeting.update_envelope/3` in `test/xactions/budgeting_test.exs`: success case updates name and replaces category assignments atomically; empty category_ids is allowed at context level (validation is LiveView responsibility); invalid changeset returns error
- [X] T012 [P] [US2] Write failing LiveView test for edit flow in `test/xactions_web/live/budget_live_test.exs`: clicking "edit_envelope" event opens edit form pre-populated; submitting with ≥ 1 category updates and closes form; submitting with zero categories shows error flash; archive item triggers existing `archive_envelope` event

### Implementation for User Story 2

- [X] T013 [US2] Implement `Budgeting.update_envelope(envelope, attrs, category_ids)` in `lib/xactions/budgeting/budgeting.ex`: update envelope fields via `BudgetEnvelope.changeset/2`, then inside `Repo.transaction/1` delete all `EnvelopeCategory` rows for this envelope and re-insert from `category_ids`; return `{:ok, envelope}` or `{:error, reason}`
- [X] T014 [US2] Add `:editing_envelope` and `:show_edit_form` assigns in `BudgetLive.mount/3` in `lib/xactions_web/live/budget_live.ex` (both default `nil`/`false`)
- [X] T015 [US2] Add `open_edit_envelope` event handler in `lib/xactions_web/live/budget_live.ex`: find envelope by id in `@envelopes`, call `Budgeting.list_available_categories(except_envelope_id: id)`, assign `:editing_envelope` and `:available_edit_categories`, set `:show_edit_form` to `true`
- [X] T016 [US2] Add `cancel_edit_envelope` event handler in `lib/xactions_web/live/budget_live.ex`: clear `:editing_envelope`, set `:show_edit_form` to `false`
- [X] T017 [US2] Add `update_envelope` event handler in `lib/xactions_web/live/budget_live.ex`: extract `category_ids`; flash error and halt if empty; call `Budgeting.update_envelope/3`; on success clear edit state and reload budget data
- [X] T018 [US2] Replace the "Archive" `<button>` in the envelope table last column with a dropdown trigger in `lib/xactions_web/live/budget_live.ex`: render a `<button phx-click={JS.toggle(to: "#dropdown-#{env.id}")} class="p-1 hover:bg-[#ececea] rounded transition-colors">` with a `hero-chevron-down` icon (matches Figma `EnvelopeGrid.tsx` trigger style); add absolutely-positioned dropdown content div `id="dropdown-#{env.id}" class="hidden ..."` with "Edit" (`phx-click="open_edit_envelope"`) and "Archive" (`phx-click="archive_envelope"`) items
- [X] T019 [US2] Add edit envelope form section in `lib/xactions_web/live/budget_live.ex` template: render inline below the table when `@show_edit_form`; pre-populate name input and category checkboxes from `@editing_envelope`; use `phx-submit="update_envelope"` and include a hidden `envelope[id]` field; category list from `@available_edit_categories`

**Checkpoint**: `mix test test/xactions_web/live/budget_live_test.exs` passes for US2 tasks. Dropdown opens/closes in browser; edit and archive both work end-to-end.

---

## Phase 5: Polish & Cross-Cutting Concerns

- [X] T020 [P] Display associated category names (comma-separated) as a subtitle under the envelope name in the table row in `lib/xactions_web/live/budget_live.ex` (uses already-preloaded `env.categories`)
- [X] T021 Run `mix credo` and resolve any warnings introduced by this feature
- [X] T022 Run `mix format` across changed files and confirm clean output

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — verify only
- **Phase 2 (Foundational)**: Depends on Phase 1 — **blocks Phase 3 and Phase 4**
- **Phase 3 (US1)**: Depends on Phase 2
- **Phase 4 (US2)**: Depends on Phase 2; independent of Phase 3 (different context function + different LiveView events)
- **Phase 5 (Polish)**: Depends on Phase 3 + Phase 4

### User Story Dependencies

- **US1 (P1)**: Foundational phase complete → can proceed
- **US2 (P2)**: Foundational phase complete → can proceed independently of US1

### Within Each User Story

- Tests (T005/T006 for US1; T011/T012 for US2) MUST be written and FAIL before implementation begins
- `Budgeting` context functions (T007, T013) before LiveView event handlers
- LiveView event handlers (T009, T015–T017) before template changes (T010, T018–T019)

### Parallel Opportunities

- T005 and T006 can run in parallel (different test files)
- T011 and T012 can run in parallel (different test files)
- T007 (US1 context) and T013 (US2 context) can run in parallel (same file, different functions — serialize writes but logic is independent)

---

## Parallel Example: User Story 1

```bash
# Write both test files in parallel:
Task T005: "Write Budgeting context tests in test/xactions/budgeting_test.exs"
Task T006: "Write BudgetLive create-flow tests in test/xactions_web/live/budget_live_test.exs"

# After tests written and confirmed failing:
Task T007: "Implement create_envelope_with_categories/2 in lib/xactions/budgeting/budgeting.ex"
# T008, T009, T010 in sequence (same file — budget_live.ex)
```

---

## Implementation Strategy

### MVP (User Story 1 Only)

1. Phase 1: Setup verification
2. Phase 2: `list_available_categories/1`
3. Phase 3: Create form with categories
4. **STOP and VALIDATE** — create envelope + categories works end-to-end
5. Demo / deploy increment

### Incremental Delivery

1. Phase 1 + 2 → foundation ready
2. Phase 3 → create with categories works (MVP)
3. Phase 4 → dropdown + edit works
4. Phase 5 → polish

---

## Notes

- [P] tasks involve different files or independent logic — safe to run in parallel
- Each test task must **fail** before its corresponding implementation task begins (constitution §II)
- The dropdown trigger (`hero-chevron-down` + `JS.toggle`) matches the Figma `EnvelopeGrid.tsx` design adapted for LiveView — no Alpine.js or JavaScript hooks needed
- Category exclusivity (one category per envelope) is enforced at DB level; the UI filters available options; no extra validation needed in the context layer
