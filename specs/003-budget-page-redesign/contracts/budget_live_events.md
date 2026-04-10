# Contract: BudgetLive Events

LiveView events exposed by `XactionsWeb.BudgetLive` at `/budget`.

---

## Events (client → server)

### `prev_month`

Navigate to the previous calendar month.

**Payload**: none

**Effect**: `date` assign shifts back one month; all budget data reloads for
the new month.

**Response**: Page re-renders with updated month heading, summary cards, and
envelope table.

---

### `next_month`

Navigate to the next calendar month.

**Payload**: none

**Effect**: `date` assign shifts forward one month.

**Response**: Same as `prev_month`.

---

### `edit_envelope`

Begin inline editing of an envelope's budgeted amount.

**Payload**:
```
%{"id" => integer_string}
```

**Effect**: `editing_envelope_id` assign set to the given id. The budgeted
cell for that row renders as an `<input>` instead of a button.

**Response**: Targeted re-render of the affected row.

---

### `cancel_edit`

Cancel inline editing without saving.

**Payload**: none

**Effect**: `editing_envelope_id` assign set to `nil`.

---

### `set_allocation`

Save the budgeted amount for an envelope in the current month.

**Payload**:
```
%{"envelope_id" => integer_string, "amount" => decimal_string}
```

**Validation**:
- `amount` must parse as a non-negative decimal.
- `envelope_id` must reference an active envelope.

**Effect**: Upserts a `BudgetMonth` record for the envelope + current month.
Clears `editing_envelope_id`.

**Error**: Flash `:error` on parse failure; socket unchanged on not-found.

---

### `open_create_envelope`

Show the create-envelope form.

**Payload**: none

**Effect**: `show_create_form` assign set to `true`.

---

### `cancel_create_envelope`

Hide the create-envelope form without saving.

**Payload**: none

**Effect**: `show_create_form` assign set to `false`.

---

### `create_envelope`

Create a new budget envelope.

**Payload**:
```
%{"envelope" => %{"name" => string, "type" => string}}
```

**Validation**: Name required; type must be one of `fixed`, `variable`,
`rollover`.

**Effect**: Inserts a `BudgetEnvelope` with a palette color auto-assigned.
Closes the create form and reloads envelope list.

**Error**: Flash `:error` with changeset message on validation failure.

---

### `archive_envelope`

Soft-delete an envelope.

**Payload**:
```
%{"id" => integer_string}
```

**Effect**: Sets `archived_at` on the envelope. Envelope disappears from the
table.

**Error**: Silently no-ops if envelope id not found.

---

## Assigns (server → client)

| Assign               | Type               | Description                                          |
|----------------------|--------------------|------------------------------------------------------|
| `date`               | `%Date{}`          | Currently viewed month                               |
| `envelopes`          | list of maps       | Active envelopes with `:budgeted`, `:spent`, `:remaining`, `:color` |
| `monthly_income`     | `Decimal.t()`      | Total income transactions for the month              |
| `total_allocated`    | `Decimal.t()`      | Sum of all envelope allocations for the month        |
| `total_spent`        | `Decimal.t()`      | Sum of all envelope spending for the month           |
| `unallocated`        | `Decimal.t()`      | `monthly_income - total_allocated`                   |
| `editing_envelope_id`| integer or `nil`   | ID of the envelope currently being edited inline     |
| `show_create_form`   | boolean            | Whether the create-envelope form is visible          |
| `unassigned`         | list               | Transactions not mapped to any active envelope       |
| `categories`         | list               | All categories (used by create-envelope form)        |
