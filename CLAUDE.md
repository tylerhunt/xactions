# xactions Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-04-10

## Active Technologies
- Elixir 1.17+ / OTP 27 + Phoenix 1.8.5, Phoenix LiveView 1.1.x, DaisyUI (already installed via `assets/vendor/daisyui.js`), Tailwind CSS (002-site-navigation-menu)
- N/A — navigation is stateless (002-site-navigation-menu)
- SQLite via `ecto_sqlite3` (003-budget-page-redesign)

- Elixir ~> 1.17, Erlang/OTP 27 + Phoenix ~> 1.7, Phoenix LiveView ~> 1.0, ecto_sqlite3, (001-personal-accounting)

## Project Structure

```text
lib/xactions/          # Domain contexts (accounts, transactions, portfolio, reporting, sync)
lib/xactions_web/      # Phoenix web layer (live/, components/, router.ex)
lib/xactions/sync/scrapers/  # Institution-specific Playwright scraper modules
priv/repo/migrations/  # Ecto migrations (9 total — see specs/001-personal-accounting/data-model.md)
test/                  # ExUnit tests; test/fixtures/ofx/ for OFX parser fixtures
specs/001-personal-accounting/  # Feature spec, plan, data model, contracts, quickstart
```

## Commands

```bash
mix setup              # Install deps + create DB + compile assets
mix phx.server         # Start dev server at http://localhost:4000
mix test               # Run all tests
mix test --exclude browser   # Skip Playwright scraper tests
mix ecto.migrate       # Run pending migrations
mix ecto.reset         # Drop + recreate + migrate + seed DB
```

## Code Style

- Elixir standard formatting (`mix format`); enforce in CI.
- Context modules expose a public API; schemas are private to their context.
- All `cloak_ecto` encrypted fields use `Cloak.Ecto.Binary` type.
- Scraper modules implement `Xactions.Sync.ScraperBehaviour`; one file per institution.
- OFX parsing lives in `Xactions.Sync.OFX`; CSV in `Xactions.Sync.CSVParser`.
- LiveView events follow the contracts in `specs/001-personal-accounting/contracts/`.

## Recent Changes
- 003-budget-page-redesign: Added Elixir 1.17+ / OTP 27 + Phoenix 1.8.5, Phoenix LiveView 1.1.x, DaisyUI
- 002-site-navigation-menu: Added Elixir 1.17+ / OTP 27 + Phoenix 1.8.5, Phoenix LiveView 1.1.x, DaisyUI (already installed via `assets/vendor/daisyui.js`), Tailwind CSS

- 001-personal-accounting: Added Elixir ~> 1.17, Erlang/OTP 27 + Phoenix ~> 1.7, Phoenix LiveView ~> 1.0, ecto_sqlite3,

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
