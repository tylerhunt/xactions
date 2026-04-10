# Quickstart: Budget Page Redesign

## What's Changing

1. **New migration** — adds `color` to `budget_envelopes`
2. **`Budgeting` context** — promotes `total_income/1`, `total_allocated/1`;
   adds `total_spent/1`; updates `BudgetEnvelope` changeset to handle `color`
3. **`BudgetLive`** — full rewrite: sticky layout, summary cards, table,
   month navigation, click-to-edit; no DaisyUI classes
4. **`layouts.ex`** — navbar rewritten in raw Tailwind (sticky, backdrop-blur);
   no DaisyUI classes
5. **`app.css`** — no changes to DaisyUI tokens; Figma colors used as Tailwind
   arbitrary values directly in templates

## DaisyUI Note

DaisyUI remains installed. Other pages still use it. This feature does not
touch other pages. A follow-on feature should migrate remaining pages and
uninstall DaisyUI.

## Setup After Pulling

```bash
mix ecto.migrate          # applies the color column migration
mix phx.server            # dev server at http://localhost:4000
```

## Running Tests

```bash
mix test                                              # full suite
mix test test/xactions/budgeting/                     # context unit tests
mix test test/xactions_web/live/budget_live_test.exs  # LiveView tests
```

## Key Files

| File | Role |
|------|------|
| `priv/repo/migrations/*_add_color_to_budget_envelopes.exs` | DB migration |
| `lib/xactions/budgeting/budget_envelope.ex` | Schema + changeset |
| `lib/xactions/budgeting/budgeting.ex` | Context — income/allocated/spent |
| `lib/xactions_web/live/budget_live.ex` | LiveView — full rewrite |
| `lib/xactions_web/components/layouts.ex` | Navbar — raw Tailwind rewrite |
| `test/xactions_web/live/budget_live_test.exs` | LiveView integration tests |
| `test/xactions/budgeting/budgeting_test.exs` | Context unit tests |

## TDD Order

1. Write failing tests for `total_income/1`, `total_allocated/1`,
   `total_spent/1` in `budgeting_test.exs`
2. Promote/add those functions in `budgeting.ex` → green
3. Write failing tests for `color` field on envelope creation
4. Add migration + changeset changes → green
5. Write failing LiveView tests for: month navigation, summary cards, table
   rendering, inline editing, color dot in each row
6. Rewrite `BudgetLive` → green
7. Rewrite `layouts.ex` navbar → verify existing nav tests pass
