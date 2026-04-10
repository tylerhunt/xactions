# Research: Site Navigation Menu

## DaisyUI Navbar Component

- **Decision**: Use DaisyUI `navbar` class with `navbar-start` / `navbar-end` slots.
- **Rationale**: Already installed in the project; provides responsive flex layout out of the box; consistent with existing DaisyUI usage across all LiveViews (cards, tables, buttons).
- **Alternatives considered**: Custom Tailwind flex header — rejected; DaisyUI navbar already provides the right semantics and responsive behaviour.

## Active Link Highlighting

- **Decision**: Assign `current_path` via an `on_mount` hook using `attach_hook/4` on `:handle_params`.
- **Rationale**: `handle_params` fires on every LiveView navigation, keeping the active state accurate after client-side patch navigation. Assigning in a single `on_mount` avoids duplicating logic in every LiveView.
- **Alternatives considered**:
  - Per-LiveView `mount` assign — rejected; requires touching 6 files.
  - CSS `:current` selector tricks — rejected; brittle, non-standard in this stack.

## LiveView Inner Layout via `live_session`

- **Decision**: Wrap all authenticated `live/3` routes in a `live_session` block with `layout: {XactionsWeb.Layouts, :app}` and `on_mount: XactionsWeb.NavHooks`.
- **Rationale**: Single declaration in the router; no per-LiveView changes needed; `live_session` is the Phoenix-idiomatic way to apply shared layout + mount hooks to a group of routes.
- **Alternatives considered**: Setting layout in each LiveView's `mount` — rejected; violates DRY and requires touching 6 files.

## Sign Out Link

- **Decision**: Use `<.link href={~p"/logout"} method="delete">` in the navbar layout.
- **Rationale**: `SessionController.delete/2` already exists and handles the logout correctly. Phoenix's `link` component with `method="delete"` generates a CSRF-safe form; no new controller code needed.
- **Alternatives considered**: LiveView `phx-click` event calling an API — rejected; session management belongs in the controller layer.

## Root Path Redirect for Unauthenticated Users

- **Decision**: No new code needed.
- **Rationale**: `AuthPlug` already redirects all unauthenticated requests (including `/`) to `/login`. FR-010 is satisfied by existing infrastructure.
