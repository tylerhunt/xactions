# Implementation Plan: Budget Page Redesign

**Branch**: `003-budget-page-redesign` | **Date**: 2026-04-10 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/003-budget-page-redesign/spec.md`

## Summary

Redesign the budget page to match the Figma Make prototype: replace the
per-envelope card layout with a single table, add four summary cards (income /
allocated / spent / unallocated), add prev/next month navigation, and add a
per-envelope color indicator. Apply the same warm neutral visual language to
the global app layout (sticky blurred navbar, warm off-white background, white
card surfaces) by updating the DaisyUI light theme tokens.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27
**Primary Dependencies**: Phoenix 1.8.5, Phoenix LiveView 1.1.x, DaisyUI
(installed via `assets/vendor/daisyui.js`), Tailwind CSS, ecto_sqlite3
**Storage**: SQLite via `ecto_sqlite3`
**Testing**: ExUnit + `Phoenix.LiveViewTest`
**Target Platform**: Web (desktop-first, responsive)
**Project Type**: Web application (Phoenix LiveView, no separate frontend)
**Performance Goals**: Month navigation re-render < 500ms p95 (well within
LiveView's typical diff-patch latency for this data volume)
**Constraints**: No new JS libraries; CSS-only animations; no dark mode in
this iteration
**Scale/Scope**: Single-user personal finance app; envelope count expected
< 20 per month

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Code Quality — simplest solution | ✅ PASS | No new abstractions; existing context functions promoted, not duplicated |
| II. TDD — tests first | ✅ PASS | quickstart.md prescribes TDD order; tasks will enforce red-first |
| III. Integration tests against real DB | ✅ PASS | Existing `BudgetLiveTest` pattern uses `ConnCase` + real SQLite |
| IV. UX consistency | ✅ PASS | Global layout updated consistently; no new interaction patterns beyond click-to-edit (low risk) |
| V. Performance documented | ✅ PASS | `< 500ms p95` documented above |

**Post-Phase-1 re-check**: No violations. The color migration is additive and
nullable; no existing query paths are broken. The three promoted context
functions (`total_income/1`, `total_allocated/1`, `total_spent/1`) are simple
query extractions with no new logic.

## Project Structure

### Documentation (this feature)

```text
specs/003-budget-page-redesign/
├── plan.md                          # This file
├── research.md                      # Phase 0 — decisions logged
├── data-model.md                    # Phase 1 — schema change + API
├── quickstart.md                    # Phase 1 — setup + TDD order
├── contracts/
│   └── budget_live_events.md        # LiveView event + assign contracts
└── tasks.md                         # Phase 2 — /speckit.tasks output
```

### Source Code

```text
priv/repo/migrations/
└── TIMESTAMP_add_color_to_budget_envelopes.exs   ← NEW

lib/xactions/budgeting/
├── budget_envelope.ex     ← add :color cast + validate + default palette
└── budgeting.ex           ← promote total_income/1, total_allocated/1;
                              add total_spent/1

lib/xactions_web/
├── live/
│   └── budget_live.ex     ← full render redesign + new events + assigns
└── components/
    └── layouts.ex          ← navbar: sticky + backdrop-blur

assets/css/
└── app.css                 ← light theme: --color-base-100 → #f8f7f5,
                               update base-200, base-300, error, primary

test/
├── xactions/budgeting/
│   └── budgeting_test.exs  ← new tests for promoted/added functions
└── xactions_web/live/
    └── budget_live_test.exs ← updated + new tests for all new behavior
```

**Structure Decision**: Single Phoenix project; no structural changes —
modifications are confined to existing files plus one new migration.

## Complexity Tracking

No constitution violations requiring justification.
