# Contract: Navigation Layout

## Component: `XactionsWeb.Layouts.app/1`

Renders the authenticated app shell: DaisyUI navbar + inner page content + flash group.

### Required assigns (injected by LiveView runtime)

| Assign | Type | Source |
|--------|------|--------|
| `@flash` | `map` | LiveView flash |
| `@current_path` | `string` | `XactionsWeb.NavHooks.on_mount/4` |
| `@inner_block` | slot | LiveView render output |

### Rendered structure

```
<div class="navbar ...">
  navbar-start: site name link (→ /)
  navbar-end:
    - Dashboard link    active when @current_path == "/"
    - Accounts link     active when @current_path == "/accounts"
    - Transactions link active when @current_path == "/transactions"
    - Portfolio link    active when @current_path == "/portfolio"
    - Budget link       active when @current_path == "/budget"
    - Reports link      active when @current_path == "/reports"
    - Sign Out link     always present (DELETE /logout)
</div>
<main>
  {render_slot(@inner_block)}
</main>
<.flash_group flash={@flash} />
```

### Active link behaviour

- Exactly one nav link carries the `active` DaisyUI modifier at any time.
- If `@current_path` matches no nav item, no link is active.

---

## Module: `XactionsWeb.NavHooks`

Provides `on_mount/4` for use in `live_session`.

### Callback: `on_mount(:default, _params, _session, socket)`

Returns `{:cont, socket}` with an `attach_hook` on `:handle_params` that assigns
`current_path` (string, e.g. `"/accounts"`) on every navigation.

### Invariants

- `current_path` is always a string; never nil.
- The hook does not halt or redirect; authentication is handled by `AuthPlug` upstream.
