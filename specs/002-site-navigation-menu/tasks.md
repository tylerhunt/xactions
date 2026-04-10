# Tasks: Site Navigation Menu

**Input**: Design documents from `/specs/002-site-navigation-menu/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, contracts/liveview-nav.md ✅, quickstart.md ✅

**Note**: TDD is mandatory per the project constitution. Test tasks precede every implementation task. Tests must be written, reviewed, and confirmed to fail before implementation begins.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to
- Exact file paths included in all descriptions

---

## Phase 1: Setup

**Purpose**: Confirm existing infrastructure before making changes.

- [X] T001 Verify DaisyUI `navbar` class is available by checking `assets/vendor/daisyui.js` for the navbar component definition

**Checkpoint**: DaisyUI navbar confirmed available — proceed to Foundational phase.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Create the `NavHooks` module and wire up `live_session` in the router. Both are required before any user story can be implemented or tested.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T002 Write a failing test asserting that `XactionsWeb.NavHooks.on_mount(:default, ...)` assigns `current_path` to the socket in `test/xactions_web/live/navigation_test.exs`
- [X] T003 Create `XactionsWeb.NavHooks` module with `on_mount(:default, ...)` that uses `attach_hook/4` on `:handle_params` to assign `current_path` from `URI.parse(url).path` in `lib/xactions_web/live/nav_hooks.ex`
- [X] T004 Update the authenticated `scope` in `lib/xactions_web/router.ex` to wrap all six `live` routes in a `live_session :authenticated` block with `layout: {XactionsWeb.Layouts, :app}` and `on_mount: XactionsWeb.NavHooks`

**Checkpoint**: `NavHooks` module compiles, router compiles with `live_session`, foundational test passes — user story phases can now begin.

---

## Phase 3: User Story 1 — Navigate to Any Section (Priority: P1) 🎯 MVP

**Goal**: Every authenticated page shows a persistent navbar with links to all six sections.

**Independent Test**: Load any authenticated page; confirm navbar is present and all six section links are rendered.

### Tests (write first — must FAIL before T006)

- [X] T005 [P] [US1] Write failing test asserting the navbar renders with links to Dashboard (`/`), Accounts (`/accounts`), Transactions (`/transactions`), Portfolio (`/portfolio`), Budget (`/budget`), and Reports (`/reports`) on the dashboard page in `test/xactions_web/live/navigation_test.exs`

### Implementation

- [X] T006 [US1] Replace the placeholder `app/1` function in `lib/xactions_web/components/layouts.ex` with a DaisyUI `navbar` containing: navbar-start with "xactions" brand link to `~p"/"`, navbar-end with `<.link navigate={~p"..."}>` for each of the six sections, a `<main>` wrapper for `render_slot(@inner_block)`, and `<.flash_group flash={@flash} />`

**Checkpoint**: All six section links render on every authenticated page — US1 independently testable and functional.

---

## Phase 4: User Story 2 — Know Where You Are (Priority: P2)

**Goal**: The nav link corresponding to the current page is visually highlighted; all others are not.

**Independent Test**: Navigate to each of the six sections; confirm only the corresponding nav link has the `btn-active` class.

### Tests (write first — must FAIL before T009)

- [X] T007 [P] [US2] Write failing test asserting the Dashboard nav link has the `btn-active` class when visiting `"/"` in `test/xactions_web/live/navigation_test.exs`
- [X] T008 [P] [US2] Write failing test asserting the Accounts nav link has the `btn-active` class when visiting `"/accounts"`, and the Dashboard link does not in `test/xactions_web/live/navigation_test.exs`

### Implementation

- [X] T009 [US2] Add a private `nav_link_class/2` helper to `lib/xactions_web/components/layouts.ex` that returns `"btn btn-ghost btn-sm"` plus `" btn-active"` when the given path matches `@current_path`, and apply it to each section link in the `app/1` layout

**Checkpoint**: Exactly one nav link is highlighted per page — US2 independently testable and functional.

---

## Phase 5: User Story 3 — Authentication State in Nav (Priority: P2)

**Goal**: Authenticated users see a Sign Out link; unauthenticated users are redirected to `/login` before reaching the navbar.

**Independent Test**: Confirm Sign Out link is present and functional when authenticated; confirm unauthenticated requests to `/` redirect to `/login`.

### Tests (write first — must FAIL before T012)

- [X] T010 [P] [US3] Write failing test asserting the navbar contains a Sign Out element that targets `"/logout"` when the user is authenticated in `test/xactions_web/live/navigation_test.exs`
- [X] T011 [P] [US3] Write failing test asserting an unauthenticated `GET /` request redirects to `"/login"` in `test/xactions_web/live/navigation_test.exs`

### Implementation

- [X] T012 [US3] Add `<.link href={~p"/logout"} method="delete">Sign Out</.link>` to the navbar-end in `lib/xactions_web/components/layouts.ex`, after the section links

**Note**: FR-010 (unauthenticated `/` → `/login`) is already satisfied by the existing `AuthPlug`. T011 verifies this existing behavior; no new implementation is required.

**Checkpoint**: Sign Out link renders and redirects to `/login`; unauthenticated redirect verified — US3 independently testable and functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Clean up, verify no regressions, confirm mobile rendering.

- [X] T013 Remove the unused Phoenix default content from `app/1` in `lib/xactions_web/components/layouts.ex` (old website/GitHub links, unused `@current_scope` attr, `theme_toggle` call) if not used elsewhere; keep the `theme_toggle/1` and `flash_group/1` helper functions
- [X] T014 Run `mix test` to confirm all existing LiveView tests and new navigation tests pass with zero failures
- [X] T015 Manually verify the navbar renders correctly at 375px viewport width using browser dev tools — confirm all links are visible and tappable without overflow

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2
- **US2 (Phase 4)**: Depends on Phase 3 (active state builds on nav links existing)
- **US3 (Phase 5)**: Depends on Phase 3 (auth state extends existing navbar)
- **Polish (Phase 6)**: Depends on all user story phases

### User Story Dependencies

- **US1 (P1)**: Foundational must be complete; no other story dependency
- **US2 (P2)**: US1 must be complete (active class applied to links created in US1)
- **US3 (P2)**: US1 must be complete; independent of US2 (can run in parallel with US2 if on different files — but both modify `layouts.ex`, so run sequentially)

### Within Each Phase

1. Write tests → confirm they FAIL → get user review
2. Implement → confirm tests PASS
3. Commit before moving to next phase

---

## Parallel Execution Opportunities

```
# Phase 2: Foundational tests can be written in parallel with NavHooks implementation
# (T002 and T003 touch different files)
Task T002: navigation_test.exs (test file)
Task T003: nav_hooks.ex (new module)

# Phase 3: US1 test can be written before/during layout work
Task T005: navigation_test.exs
Task T006: layouts.ex (after T005 confirmed failing)

# Phase 4: Both US2 tests can be written in parallel
Task T007: navigation_test.exs (dashboard active)
Task T008: navigation_test.exs (accounts active)

# Phase 5: Both US3 tests can be written in parallel
Task T010: navigation_test.exs (sign out present)
Task T011: navigation_test.exs (unauthenticated redirect)
```

---

## Implementation Strategy

### MVP (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (NavHooks + live_session)
3. Complete Phase 3: US1 (navbar with section links)
4. **STOP and VALIDATE**: All six links render and navigate correctly
5. US2 and US3 can follow as incremental additions

### Incremental Delivery

1. Setup + Foundational → infrastructure ready
2. US1 → persistent navbar with section links (MVP)
3. US2 → active link highlighting
4. US3 → Sign Out link + auth state verification
5. Polish → cleanup and mobile check
