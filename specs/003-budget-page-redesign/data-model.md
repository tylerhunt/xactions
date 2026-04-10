# Data Model: Budget Page Redesign

## Schema Change: `budget_envelopes.color`

**Migration**: Add `color` string column to `budget_envelopes`.

```
budget_envelopes
├── id             integer, PK
├── name           string, NOT NULL
├── type           string, NOT NULL  (fixed | variable | rollover)
├── color          string            ← NEW: hex color, e.g. "#10b981"
├── rollover_cap   decimal(15,2)
├── archived_at    utc_datetime
├── inserted_at    utc_datetime
└── updated_at     utc_datetime
```

**Validation**: `color` must match `~r/^#[0-9a-fA-F]{6}$/` when present.
Nullable at the DB level; context assigns a palette color on creation if
not provided.

**Default palette** (assigned cyclically by total envelope count at creation):

```
"#10b981"  emerald
"#3b82f6"  blue
"#f59e0b"  amber
"#ec4899"  pink
"#8b5cf6"  violet
"#06b6d4"  cyan
"#14b8a6"  teal
"#f97316"  orange
```

---

## No Other Schema Changes

All other data requirements are met by existing tables:

| Requirement           | Existing source                                              |
|-----------------------|--------------------------------------------------------------|
| Monthly income        | `transactions` filtered by income category + month          |
| Total allocated       | `budget_months.allocated_amount` summed by month            |
| Per-envelope spent    | `transactions` filtered by envelope's categories + month    |
| Per-envelope balance  | computed: `allocated - spent`                               |
| Month navigation      | `budget_months` already keyed by `month` + `year` integers  |

---

## Context API Changes

### Promoted to public

```elixir
# Xactions.Budgeting

@doc "Returns total income transactions for the given month."
def total_income(%Date{} = date) :: Decimal.t()

@doc "Returns total allocated amount across all active envelopes for the month."
def total_allocated(%Date{} = date) :: Decimal.t()
```

### New public function

```elixir
@doc "Returns total spent across all active envelopes for the month."
def total_spent(%Date{} = date) :: Decimal.t()
```

### Updated changeset

```elixir
# BudgetEnvelope.changeset/2
# Adds :color to cast fields.
# Validates hex format when present.
# Assigns a default palette color on insert if color is nil.
```

### New migration

```
priv/repo/migrations/TIMESTAMP_add_color_to_budget_envelopes.exs
```
