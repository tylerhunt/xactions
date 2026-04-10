# Quickstart: Site Navigation Menu

## Verify it works

1. Start the server: `mix phx.server`
2. Navigate to `http://localhost:4000/login` and sign in.
3. Confirm the DaisyUI navbar is visible at the top of every page.
4. Click each nav link and confirm the correct page loads and the link is highlighted.
5. Click Sign Out and confirm you are redirected to `/login`.
6. Without signing in, visit `http://localhost:4000/` — confirm redirect to `/login`.

## Run the tests

```sh
mix test test/xactions_web/live/navigation_test.exs
```

## Key files

| File | Purpose |
|------|---------|
| `lib/xactions_web/live/nav_hooks.ex` | `on_mount` hook that tracks `current_path` |
| `lib/xactions_web/components/layouts.ex` | `app/1` layout with DaisyUI navbar |
| `lib/xactions_web/router.ex` | `live_session` wrapping authenticated routes |
| `test/xactions_web/live/navigation_test.exs` | Navigation tests |
