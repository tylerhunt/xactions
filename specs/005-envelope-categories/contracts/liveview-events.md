# LiveView Event Contracts: Envelope Category Association

**Date**: 2026-04-10  
**LiveView**: `XactionsWeb.BudgetLive`

---

## New / modified events

### `open_create_envelope`

Existing event — no change to handler signature. The create form now includes
a `category_ids` field.

---

### `create_envelope`

**Trigger**: `phx-submit` on the create envelope form.

**Params**:
```
%{
  "envelope" => %{
    "name"         => string,       # required
    "type"         => string,       # "fixed" | "variable" | "rollover"
    "category_ids" => [string, ...] # list of category id strings; may be empty list
  }
}
```

**Behaviour**:
- If `category_ids` is empty → put error flash "Select at least one category"; do not save.
- Otherwise → call `Budgeting.create_envelope_with_categories(attrs, category_ids)`.
- On `{:ok, _}` → close form, reload budget data.
- On `{:error, changeset}` → put error flash with changeset errors.

**Socket assigns changed**: `:show_create_form`, `:envelopes`

---

### `open_edit_envelope`

**Trigger**: "Edit" item clicked in the envelope row dropdown.

**Params**: `%{"id" => string}`

**Behaviour**:
- Find envelope in `socket.assigns.envelopes` by id.
- Set `:editing_envelope` to the found envelope struct (with preloaded categories).
- Set `:show_edit_form` to `true`.

**Socket assigns changed**: `:editing_envelope`, `:show_edit_form`

---

### `cancel_edit_envelope`

**Trigger**: "Cancel" button in edit form.

**Params**: none

**Behaviour**: Set `:editing_envelope` to `nil`, `:show_edit_form` to `false`.

**Socket assigns changed**: `:editing_envelope`, `:show_edit_form`

---

### `update_envelope`

**Trigger**: `phx-submit` on the edit envelope form.

**Params**:
```
%{
  "envelope" => %{
    "id"           => string,       # required; identifies the envelope to update
    "name"         => string,       # required
    "type"         => string,       # "fixed" | "variable" | "rollover"
    "category_ids" => [string, ...] # list of category id strings; may be empty list
  }
}
```

**Behaviour**:
- If `category_ids` is empty → put error flash "Select at least one category"; do not save.
- Find envelope in `socket.assigns.envelopes` by id.
- Call `Budgeting.update_envelope(envelope, attrs, category_ids)`.
- On `{:ok, _}` → close edit form, reload budget data.
- On `{:error, changeset}` → put error flash with changeset errors.

**Socket assigns changed**: `:editing_envelope`, `:show_edit_form`, `:envelopes`

---

## Existing events (unchanged)

| Event              | Notes                                        |
|--------------------|----------------------------------------------|
| `prev_month`       | No change                                    |
| `next_month`       | No change                                    |
| `edit_envelope`    | Renamed concern: this still controls inline allocation edit (`editing_envelope_id`) |
| `cancel_edit`      | No change                                    |
| `cancel_create_envelope` | No change                              |
| `archive_envelope` | Moved into dropdown menu item; no handler change |
| `set_allocation`   | No change                                    |

---

## New socket assigns

| Assign              | Type                     | Default |
|---------------------|--------------------------|---------|
| `:editing_envelope` | `BudgetEnvelope.t \| nil` | `nil`  |
| `:show_edit_form`   | `boolean`                | `false` |
