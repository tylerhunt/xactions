# Implementation Plan: Site Navigation Menu

**Branch**: `002-site-navigation-menu` | **Date**: 2026-04-10 | **Spec**: [spec.md](spec.md)

## Summary

Add a persistent DaisyUI navbar to all authenticated pages showing section links with active-state highlighting and a Sign Out link. Unauthenticated users are already redirected to `/login` by the existing `AuthPlug`; no new auth plumbing is needed.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27
**Primary Dependencies**: Phoenix 1.8.5, Phoenix LiveView 1.1.x, DaisyUI (already installed via `assets/vendor/daisyui.js`), Tailwind CSS
**Storage**: N/A — navigation is stateless
**Testing**: ExUnit + Phoenix.LiveViewTest
**Target Platform**: Web browser (desktop + mobile, min 375px wide)
**Performance Goals**: Nav renders with page load; no additional round-trips
**Constraints**: Must not require per-LiveView changes; active link must update on client-side patch navigation
**Scale/Scope**: 6 authenticated pages, 1 shared layout component

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Code Quality — simplest solution | ✅ PASS | `live_session` + one `on_mount` module; no abstraction layers |
| II. Test-First Development | ✅ PASS | `navigation_test.exs` written before implementation |
| III. Integration & Contract Testing | ✅ PASS | Contract defined in `contracts/liveview-nav.md`; integration test hits real LiveView |
| IV. UX Consistency | ✅ PASS | Single navbar component; DaisyUI `active` modifier used consistently |
| V. Performance | ✅ PASS | No DB queries; nav state derived from URL path only |

## Project Structure

### Documentation (this feature)

```text
specs/002-site-navigation-menu/
├── plan.md              ← this file
├── research.md          ✅
├── contracts/
│   └── liveview-nav.md  ✅
├── quickstart.md        ✅
└── tasks.md             (created by /speckit-tasks)
```

### Source Code Changes

```text
lib/xactions_web/
├── live/
│   └── nav_hooks.ex              ← NEW: on_mount hook for current_path tracking
└── components/
    └── layouts.ex                ← MODIFY: replace placeholder app/1 with DaisyUI navbar

lib/xactions_web/router.ex        ← MODIFY: wrap authenticated live routes in live_session

test/xactions_web/live/
└── navigation_test.exs           ← NEW: navigation tests
```

**Structure Decision**: Single-project Phoenix app. No new directories needed. The navbar lives in the existing `layouts.ex` component module; the hook is a new single-purpose module in `live/`.

## Design Details

### `XactionsWeb.NavHooks`

```elixir
defmodule XactionsWeb.NavHooks do
  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:default, _params, _session, socket) do
    {:cont,
     attach_hook(socket, :set_current_path, :handle_params, fn _params, url, socket ->
       {:cont, assign(socket, :current_path, URI.parse(url).path)}
     end)}
  end
end
```

### Router `live_session`

```elixir
live_session :authenticated,
  layout: {XactionsWeb.Layouts, :app},
  on_mount: XactionsWeb.NavHooks do
  live "/", DashboardLive
  live "/accounts", AccountsLive
  live "/transactions", TransactionsLive
  live "/portfolio", PortfolioLive
  live "/budget", BudgetLive
  live "/reports", ReportsLive
end
```

### `Layouts.app/1` (DaisyUI Navbar)

Replaces the existing placeholder `app/1` function with:

- **navbar-start**: "xactions" brand link → `~p"/"`
- **navbar-end**: nav links for each section using `<.link navigate={~p"..."}>` with `btn-active` class when `@current_path` matches, plus Sign Out via `<.link href={~p"/logout"} method="delete">`
- `<main>` wrapping `render_slot(@inner_block)`
- `<.flash_group flash={@flash} />`

Active class helper: a private `nav_link_class/2` that returns the base btn classes plus `btn-active` when the path matches.

### What does NOT change

- `AuthPlug` — already handles unauthenticated redirect including `/`. FR-010 satisfied.
- `SessionController` — sign-out logic already correct.
- Individual LiveView render functions — no changes required.
- `root.html.heex` — unchanged outer HTML shell.

## Complexity Tracking

*No constitution violations.*
