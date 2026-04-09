# Implementation Plan: Personal Accounting with Multi-Institution Sync

**Branch**: `001-personal-accounting` | **Date**: 2026-04-09 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/001-personal-accounting/spec.md`

## Summary

Build a single-user personal accounting web application in Elixir/Phoenix. Bank sync
is performed by headless browser automation (Playwright) that logs into each financial
institution's website, downloads OFX/QFX/CSV transaction exports, and parses them into
a local SQLite database. Institution login credentials are stored encrypted at rest
using AES-256-GCM. The UI is Phoenix LiveView with TailwindCSS. Deployment is a single
Docker container in a homelab environment behind Traefik.

## Technical Context

**Language/Version**: Elixir ~> 1.17, Erlang/OTP 27
**Primary Dependencies**: Phoenix ~> 1.7, Phoenix LiveView ~> 1.0, ecto_sqlite3,
`playwright` (hex, Elixir bindings for Playwright), `cloak_ecto` ~> 1.3,
`req` ~> 0.5, `bcrypt_elixir` ~> 3.0, TailwindCSS (via Phoenix assets),
Node.js ~> 20 (runtime dependency for Playwright browser server)
**Storage**: SQLite via ecto_sqlite3, WAL mode, Docker volume-mounted at
`/app/data/xactions.db`
**Testing**: ExUnit; real SQLite in-memory DB for integration tests (no mocks);
Playwright scraper contract tests tagged `@tag :browser` (run separately)
**Target Platform**: Linux (Docker), homelab behind Traefik, single container
**Project Type**: Web application — Phoenix LiveView UI, no separate frontend build
**Performance Goals**: Dashboard p95 < 2s; transaction search p95 < 500ms;
manual sync visible progress within 2s of trigger; full sync completes in < 60s
per institution
**Constraints**: Single user; bank credentials encrypted at rest; no external API
services; SQLite only; MFA (TOTP auto-resolved; SMS/push via UI prompt)
**Scale/Scope**: Single user; ~50k transactions max; ~100 holdings; 1 concurrent user

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Code Quality | ✅ PASS | Single Phoenix app; scraper modules are the only place with institution-specific logic; each context has one responsibility |
| II. Test-First (NON-NEGOTIABLE) | ✅ PASS | All tasks require failing tests before implementation; scraper contract tests written first against real institution (or recorded fixture) |
| III. Integration & Contract Testing | ✅ PASS | OFX parser has tests against real OFX file fixtures; scraper behaviour has contract tests; LiveView has integration tests against real SQLite; no DB mocks |
| IV. UX Consistency | ✅ PASS | Shared error component (what/why/how); MFA flow uses a single consistent modal pattern; all forms use the same component library |
| V. Performance Requirements | ✅ PASS | p95 targets documented above; sync duration tracked in `SyncLog`; dashboard load benchmarked in CI |

**No violations. No complexity justification required.**

## Project Structure

### Documentation (this feature)

```text
specs/001-personal-accounting/
├── plan.md                        # This file
├── research.md                    # Phase 0 output
├── data-model.md                  # Phase 1 output
├── quickstart.md                  # Phase 1 output
├── contracts/
│   ├── scraper-behaviour.md       # ScraperBehaviour + OFX parser interface
│   └── liveview-events.md         # LiveView socket event contracts
└── tasks.md                       # Phase 2 output (/speckit.tasks — not yet created)
```

### Source Code (repository root)

```text
lib/
├── xactions/
│   ├── accounts/
│   │   ├── institution.ex          # Institution schema + changeset (encrypted fields)
│   │   ├── account.ex              # Account schema + changeset
│   │   └── accounts.ex             # Accounts context (public API)
│   ├── transactions/
│   │   ├── transaction.ex          # Transaction schema + changeset
│   │   ├── transaction_split.ex    # TransactionSplit schema
│   │   ├── category.ex             # Category schema
│   │   ├── merchant_rule.ex        # MerchantCategoryRule schema
│   │   └── transactions.ex         # Transactions context
│   ├── portfolio/
│   │   ├── holding.ex              # Holding schema + changeset
│   │   └── portfolio.ex            # Portfolio context
│   ├── reporting/
│   │   ├── budget_target.ex        # BudgetTarget schema
│   │   └── reporting.ex            # Reporting context (net worth, spending)
│   ├── sync/
│   │   ├── scraper_behaviour.ex    # @behaviour definition (see contracts/scraper-behaviour.md)
│   │   ├── sync_scheduler.ex       # GenServer — daily scheduling + manual trigger
│   │   ├── sync_worker.ex          # Orchestrates one institution sync end-to-end
│   │   ├── ofx.ex                  # OFX 1.x SGML + 2.x XML parser
│   │   ├── csv_parser.ex           # CSV fallback parser (per-institution column maps)
│   │   ├── sync_log.ex             # SyncLog schema
│   │   └── scrapers/
│   │       └── example_bank.ex     # Reference scraper implementation (for docs)
│   ├── vault.ex                    # Cloak AES-256-GCM vault definition
│   └── repo.ex
│
├── xactions_web/
│   ├── live/
│   │   ├── dashboard_live.ex
│   │   ├── accounts_live.ex
│   │   ├── transactions_live.ex
│   │   ├── portfolio_live.ex
│   │   ├── reports_live.ex
│   │   └── mfa_live.ex             # MFA code entry modal (embedded component)
│   ├── components/
│   │   ├── core_components.ex      # Phoenix-generated shared components
│   │   ├── account_card.ex
│   │   ├── transaction_row.ex
│   │   ├── category_select.ex
│   │   ├── net_worth_widget.ex
│   │   ├── sync_status_badge.ex
│   │   └── chart_component.ex      # Portfolio + net worth charts
│   └── router.ex
│
priv/
├── repo/
│   └── migrations/                 # 9 migration files (see data-model.md)
└── static/

test/
├── xactions/
│   ├── accounts/
│   ├── transactions/
│   ├── portfolio/
│   ├── reporting/
│   └── sync/
│       ├── ofx_test.exs            # OFX parser unit tests (fixture files in test/fixtures/ofx/)
│       ├── csv_parser_test.exs
│       └── sync_worker_test.exs    # Integration tests with fake scraper
├── xactions_web/
│   └── live/                       # LiveView integration tests
└── support/
    ├── fixtures.ex
    ├── conn_case.ex
    └── fake_scraper.ex             # Test double implementing ScraperBehaviour

test/fixtures/
└── ofx/
    ├── checking_sample.ofx         # Real OFX fixture for parser tests
    ├── brokerage_sample.ofx
    └── credit_card_sample.ofx

config/
├── config.exs
├── dev.exs
├── test.exs
└── runtime.exs                     # Reads DATABASE_PATH, CLOAK_KEY, etc.

Dockerfile                          # Multi-stage: build on Elixir image, runtime on Playwright image
docker-compose.yml
.env.example
```

**Structure Decision**: Single Phoenix application. No separate frontend/backend split.
LiveView handles all UI over WebSocket. Playwright runs as a subprocess managed by the
application supervisor via `playwright-elixir`. The `scrapers/` directory is the
extension point — each new institution gets one file implementing `ScraperBehaviour`.

## Phase 0: Research Output

All decisions documented in [research.md](research.md). Summary:

| Decision | Choice | Key Reason |
|----------|--------|------------|
| Bank sync mechanism | Playwright headless browser + OFX/CSV export | Fully self-hosted; no API costs; institution-specific scraper modules |
| OFX parsing | Internal `Xactions.Sync.OFX` module | Minimal subset needed; ~150 lines; no dep required |
| CSV fallback | Internal `Xactions.Sync.CSVParser` with per-institution column maps | No standard schema; column mapping config is institution-specific |
| OFX Direct Connect | Supported as `sync_method: :ofx_direct` alternative | Faster and more reliable where available; avoids browser overhead |
| Playwright integration | `playwright` hex package (Elixir bindings) | Keeps orchestration in Elixir GenServer; no Erlang Port boilerplate |
| Credential encryption | `cloak_ecto` (AES-256-GCM) | Field-level encryption; authenticated; minimal boilerplate |
| Background sync | `GenServer` + `Process.send_after` | Zero deps; sufficient for single-user daily schedule |
| SQLite adapter | `ecto_sqlite3`, WAL mode | Only maintained Elixir adapter; WAL for concurrent read/write |
| HTTP client | `Req` ~> 0.5 | Used for OFX Direct Connect; minimal dep chain |
| Auth | `bcrypt_elixir` + Phoenix sessions | Single user, homelab |
| Docker runtime | Playwright base image (`mcr.microsoft.com/playwright`) | Includes Chromium; add Erlang runtime on top |

## Phase 1: Design Output

| Artifact | Status | Path |
|----------|--------|------|
| Data model | ✅ Complete | [data-model.md](data-model.md) |
| Scraper behaviour + OFX parser contract | ✅ Complete | [contracts/scraper-behaviour.md](contracts/scraper-behaviour.md) |
| LiveView event contracts | ✅ Complete | [contracts/liveview-events.md](contracts/liveview-events.md) |
| Quickstart | ✅ Complete | [quickstart.md](quickstart.md) |

## Complexity Tracking

> No constitution violations. Listed for dependency justification only.

| Dependency | Justification |
|------------|---------------|
| `playwright` (hex) | Headless browser automation is the core sync mechanism; no lighter alternative exists for navigating modern bank web UIs |
| `cloak_ecto` | Actual bank credentials stored at rest; AES-256-GCM authenticated encryption is non-negotiable; writing this safely from scratch invites errors |
| `req` | HTTP client needed for OFX Direct Connect; Req is the minimal choice (1 dep vs HTTPoison/hackney chain) |
| `bcrypt_elixir` | Secure password hashing; not implementable safely without a hardened library |
| Node.js (runtime) | Required by the `playwright` package's browser server; not a Hex dep but a Docker image dependency |
