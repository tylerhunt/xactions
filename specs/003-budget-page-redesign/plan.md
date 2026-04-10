# Implementation Plan: Budget Page Redesign

**Branch**: `003-budget-page-redesign` | **Date**: 2026-04-10 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/003-budget-page-redesign/spec.md`

## Summary

Redesign the budget page to match the Figma Make prototype: replace the
per-envelope card layout with a single table, add four summary cards (income /
allocated / spent / unallocated), add prev/next month navigation, and add a
per-envelope color indicator. Rewrite the global navbar to raw Tailwind (sticky,
backdrop-blur). Zero DaisyUI classes in any new code; DaisyUI stays installed
for existing pages but is not touched.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27
**Primary Dependencies**: Phoenix 1.8.5, Phoenix LiveView 1.1.x, Tailwind CSS
(DaisyUI installed but not used in new code)
**Storage**: SQLite via `ecto_sqlite3`
**Testing**: ExUnit + `Phoenix.LiveViewTest`
**Target Platform**: Web (desktop-first, responsive)
**Project Type**: Web application (Phoenix LiveView, no separate frontend)
**Performance Goals**: Month navigation re-render < 500ms p95
**Constraints**: No new JS libraries; no DaisyUI classes in new code;
CSS-only progress bar animation; dark mode out of scope for this iteration
**Scale/Scope**: Single-user personal finance app; < 20 envelopes expected

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Code Quality — simplest solution | ✅ PASS | No new abstractions; existing context functions promoted/extracted, not duplicated |
| II. TDD — tests first | ✅ PASS | quickstart.md prescribes TDD order; all implementation tasks are preceded by test tasks |
| III. Integration tests against real DB | ✅ PASS | Existing `ConnCase` + real SQLite pattern continues |
| IV. UX consistency | ✅ PASS | New code uses consistent Tailwind arbitrary-value tokens; DaisyUI pages untouched |
| V. Performance documented | ✅ PASS | `< 500ms p95` for month navigation documented above |

No violations. The color migration is additive and nullable; no existing
query paths are affected.

## Project Structure

### Documentation (this feature)

```text
specs/003-budget-page-redesign/
├── plan.md                          # This file
├── research.md                      # 7 decisions logged
├── data-model.md                    # color column + promoted context API
├── quickstart.md                    # setup + TDD order
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
│   └── budget_live.ex     ← full rewrite, raw Tailwind, no DaisyUI
└── components/
    └── layouts.ex          ← navbar rewrite: sticky, backdrop-blur, raw Tailwind

test/
├── xactions/budgeting/
│   └── budgeting_test.exs  ← new tests for promoted/added functions + color
└── xactions_web/live/
    └── budget_live_test.exs ← updated + new tests for all new behavior
```

**Structure Decision**: Single Phoenix project; no structural changes — all
modifications are to existing files plus one new migration. No new source
files needed.

## Complexity Tracking

No constitution violations requiring justification.
