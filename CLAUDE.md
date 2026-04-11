# Xactions Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-04-10

## Active Technologies
- Elixir 1.17+ / OTP 27 + Phoenix 1.8.5, Phoenix LiveView 1.1.x, Tailwind CSS, `ecto_sqlite3` (005-envelope-categories)
- SQLite — `envelope_categories` join table already migrated (005-envelope-categories)

- back end: Elixir 1.17+ / OTP 27 + Phoenix 1.8.5
- front end: Phoenix LiveView 1.1.x
- stylesheet: Tailwind CSS
- database: SQLite via `ecto_sqlite3`
- icons: Heroicons

## Design

- Figma file: https://www.figma.com/make/Dc1gifCFze6595F8BqCsgM

## Project Structure

```text
lib/xactions/          # Domain contexts (accounts, transactions, portfolio, reporting, sync)
lib/xactions_web/      # Phoenix web layer (live/, components/, router.ex)
lib/xactions/sync/scrapers/  # Institution-specific Playwright scraper modules
priv/repo/migrations/  # Ecto migrations (9 total — see specs/001-personal-accounting/data-model.md)
test/                  # ExUnit tests; test/fixtures/ofx/ for OFX parser fixtures
specs/###-feature-name # Feature spec, plan, data model, contracts, quickstart
```

## Commands

```bash
mix setup              # Install deps + create DB + compile assets
mix phx.server         # Start dev server at http://localhost:4000
mix test               # Run all tests
mix test --exclude browser   # Skip Playwright scraper tests
mix ecto.migrate       # Run pending migrations
mix ecto.reset         # Drop + recreate + migrate + seed DB
mix credo              # Run static code analysis
```

## Code Style

- Elixir standard formatting (`mix format`); enforce in CI.
- Context modules expose a public API; schemas are private to their context.
- All `cloak_ecto` encrypted fields use `Cloak.Ecto.Binary` type.
- Scraper modules implement `Xactions.Sync.ScraperBehaviour`; one file per institution.
- OFX parsing lives in `Xactions.Sync.OFX`; CSV in `Xactions.Sync.CSVParser`.
- LiveView events follow the contracts in `specs/001-personal-accounting/contracts/`.

## Recent Changes
- 005-envelope-categories: Added Elixir 1.17+ / OTP 27 + Phoenix 1.8.5, Phoenix LiveView 1.1.x, Tailwind CSS, `ecto_sqlite3`

- 003-budget-page-redesign: Added Elixir 1.17+ / OTP 27 + Phoenix 1.8.5, Phoenix LiveView 1.1.x, Tailwind CSS


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
