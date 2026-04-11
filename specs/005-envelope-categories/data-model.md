# Data Model: Envelope Category Association

**Date**: 2026-04-10

No schema changes. All required tables and associations are already in place.

---

## Existing entities (no changes)

### `budget_envelopes`

| Column        | Type     | Notes                                      |
|---------------|----------|--------------------------------------------|
| id            | integer  | PK                                         |
| name          | string   | required                                   |
| type          | string   | `fixed` \| `variable` \| `rollover`        |
| color         | string   | hex; auto-assigned from palette            |
| rollover_cap  | decimal  | rollover type only                         |
| archived_at   | datetime | null = active; set = soft-deleted          |
| inserted_at   | datetime |                                            |
| updated_at    | datetime |                                            |

### `categories`

| Column    | Type    | Notes                                      |
|-----------|---------|--------------------------------------------|
| id        | integer | PK                                         |
| name      | string  | required                                   |
| icon      | string  |                                            |
| is_system | boolean | default false                              |
| parent_id | integer | FK → categories (self-referential)         |

### `envelope_categories` (join table — already exists)

| Column             | Type     | Notes                                       |
|--------------------|----------|---------------------------------------------|
| id                 | integer  | PK                                          |
| budget_envelope_id | integer  | FK → budget_envelopes; required             |
| category_id        | integer  | FK → categories; required; **unique** — one category per envelope max |
| inserted_at        | datetime |                                             |
| updated_at         | datetime |                                             |

**Key constraint**: `UNIQUE(category_id)` — a category may belong to at most one
envelope. This is enforced at the database level and validated by `EnvelopeCategory.changeset/2`.

---

## New context functions (application layer only)

### `Budgeting.create_envelope_with_categories(attrs, category_ids)`

Wraps `create_envelope/1` + multiple `assign_category/2` calls in a single
`Repo.transaction/1`. Returns `{:ok, envelope}` or `{:error, reason}`.

### `Budgeting.update_envelope(envelope, attrs, category_ids)`

Updates envelope name/type/color via `BudgetEnvelope.changeset/2`, then
atomically replaces all `EnvelopeCategory` rows for the envelope:
delete existing → insert new. Wrapped in `Repo.transaction/1`.
Returns `{:ok, envelope}` or `{:error, reason}`.

---

## Validation rules

- An envelope must have at least one category (enforced in the LiveView
  event handler before calling the context; the context itself does not
  enforce this so it remains independently testable).
- A category already assigned to another active envelope is unavailable
  for selection (filtered out in the UI; enforced by the DB unique constraint
  as a backstop).
