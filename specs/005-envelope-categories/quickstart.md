# Quickstart: Envelope Category Association

**Date**: 2026-04-10

## What's changing

1. **`Budgeting` context** — two new functions:
   - `create_envelope_with_categories(attrs, category_ids)` — creates an envelope and assigns categories in one transaction.
   - `update_envelope(envelope, attrs, category_ids)` — updates envelope fields and atomically replaces its category assignments.

2. **`BudgetLive`** — three UI changes:
   - Create form gains a category checkbox list; submission validates at least one is selected.
   - Each envelope row in the table gains a ChevronDown dropdown trigger (inline after the envelope name) with "Edit" and "Archive" items.
   - An edit form (rendered below the table when active) lets the user rename the envelope and change its categories.

## No migration required

The `envelope_categories` table already exists. Run `mix ecto.migrate` only if
you pull changes that add new migrations (none expected for this feature).

## Running the app

```bash
mix phx.server
```

Navigate to the Budget page. Click "New Envelope" to see the updated create form.
In the Envelopes table, each row's envelope name cell now has a `⌄` button — click
it to open the dropdown, then choose "Edit".

## Running tests

```bash
mix test test/xactions/budgeting_test.exs
mix test test/xactions_web/live/budget_live_test.exs
```

Or run the full suite:

```bash
mix test
```

## Key files

| File | Purpose |
|------|---------|
| `lib/xactions/budgeting/budgeting.ex` | New context functions |
| `lib/xactions_web/live/budget_live.ex` | LiveView events + templates |
| `test/xactions/budgeting_test.exs` | Context unit/integration tests |
| `test/xactions_web/live/budget_live_test.exs` | LiveView interaction tests |
