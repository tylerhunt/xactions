# Quickstart: Budget Page Redesign

## What's Changing

1. **New migration** — adds `color` to `budget_envelopes`
2. **`Budgeting` context** — promotes `total_income/1`, `total_allocated/1`,
   and adds `total_spent/1` as public functions; updates `BudgetEnvelope`
   changeset to handle `color`
3. **`BudgetLive`** — new layout: sticky nav, summary cards, table, month nav,
   click-to-edit allocation
4. **`layouts.ex`** — sticky + backdrop-blur navbar
5. **`app.css`** — light theme color tokens updated to match Figma palette

## Setup After Pulling

```bash
mix ecto.migrate          # applies the color column migration
mix phx.server            # dev server at http://localhost:4000
```

## Running Tests

```bash
mix test                                          # full suite
mix test test/xactions/budgeting/                 # context unit tests
mix test test/xactions_web/live/budget_live_test.exs  # LiveView tests
```

## Key Files

| File | Role |
|------|------|
| `priv/repo/migrations/*_add_color_to_budget_envelopes.exs` | DB migration |
| `lib/xactions/budgeting/budget_envelope.ex` | Schema + changeset |
| `lib/xactions/budgeting/budgeting.ex` | Context — income/allocated/spent |
| `lib/xactions_web/live/budget_live.ex` | LiveView — main changes here |
| `lib/xactions_web/components/layouts.ex` | Navbar sticky + blur |
| `assets/css/app.css` | DaisyUI light theme color overrides |
| `test/xactions_web/live/budget_live_test.exs` | LiveView integration tests |
| `test/xactions/budgeting/budgeting_test.exs` | Context unit tests |

## TDD Order

Follow red-green-refactor strictly per the constitution:

1. Write failing tests for `total_income/1`, `total_allocated/1`,
   `total_spent/1` in `budgeting_test.exs`
2. Promote/add those functions in `budgeting.ex` to green
3. Write failing LiveView tests for month navigation, summary cards, table
   rendering, click-to-edit
4. Implement the `BudgetLive` changes to green
5. Write failing tests for `color` assignment on envelope creation
6. Add migration + changeset changes to green
