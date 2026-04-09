---
description: "Task list for personal accounting application with multi-institution sync"
---

# Tasks: Personal Accounting with Multi-Institution Sync

**Input**: Design documents from `specs/001-personal-accounting/`
**Prerequisites**: plan.md ✅ spec.md ✅ research.md ✅ data-model.md ✅ contracts/ ✅ quickstart.md ✅

**Tests**: Included throughout per the project constitution (Principle II — Test-First is NON-NEGOTIABLE).
All test tasks MUST be written and confirmed failing before any implementation task in the same story begins.

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no shared dependencies)
- **[Story]**: User story this task belongs to (US1–US5)
- Exact file paths included in all task descriptions

---

## Phase 1: Setup

**Purpose**: Create the Phoenix project skeleton and configure all tooling.

- [x] T001 Run `mix phx.new xactions --live --no-mailer` and commit the generated scaffold
- [x] T002 [P] Add hex dependencies to `mix.exs`: `ecto_sqlite3`, `cloak_ecto`, `playwright`, `req`, `bcrypt_elixir`, `nimble_totp`, `nimble_csv`
- [x] T003 [P] Configure `config/runtime.exs` to read `DATABASE_PATH`, `CLOAK_KEY`, `SECRET_KEY_BASE`, `PHX_HOST`, `PLAYWRIGHT_SERVER_PORT` from environment
- [x] T004 [P] Configure `ecto_sqlite3` repo in `config/config.exs` with WAL pragmas (`journal_mode=WAL`, `foreign_keys=ON`, `busy_timeout=5000`, `synchronous=NORMAL`)
- [x] T005 [P] Configure TailwindCSS via Phoenix assets pipeline in `assets/tailwind.config.js` and `assets/css/app.css`
- [x] T006 [P] Create `Dockerfile` (multi-stage: Elixir build + Playwright runtime base image) and `docker-compose.yml` with Traefik Docker labels and `./data:/app/data` volume
- [x] T007 Create `.env.example` with all required environment variables documented

**Checkpoint**: `mix deps.get && mix compile` succeeds with no errors.

---

## Phase 2: Foundational

**Purpose**: Core infrastructure required before any user story can be implemented or tested.

**⚠️ CRITICAL**: No user story work begins until this phase is complete.

- [x] T008 Create Cloak vault in `lib/xactions/vault.ex` (AES-256-GCM, reads key from `CLOAK_KEY` env var; define `Xactions.Vault` module)
- [x] T009 Create migration 001: `categories` table in `priv/repo/migrations/` (id, name, icon, parent_id, is_system, timestamps)
- [x] T010 [P] Create migration 002: `institutions` table (id, name, website_url, scraper_module, sync_method enum, ofx_direct_url, export_format enum, credential_username binary, credential_password binary, totp_seed binary, session_cookies binary, status enum, last_synced_at, sync_interval_hours, is_manual_only, timestamps)
- [x] T011 [P] Create migration 003: `accounts` table (id, institution_id FK nullable, name, type enum, balance decimal, currency, external_account_id, is_manual, is_active, timestamps)
- [x] T012 [P] Create migration 004: `transactions` table (id, account_id FK, date, amount decimal, merchant_name, raw_merchant, fit_id, notes, is_pending, is_split, is_manual, category_id FK nullable, timestamps); unique index on (account_id, fit_id)
- [x] T013 [P] Create migration 005: `transaction_splits` table (id, transaction_id FK, category_id FK, amount decimal, notes, timestamps)
- [x] T014 [P] Create migration 006: `merchant_category_rules` table (id, merchant_pattern unique, category_id FK, timestamps)
- [x] T015 [P] Create migration 007: `holdings` table (id, account_id FK, symbol, name, quantity decimal, cost_basis decimal, current_price decimal, price_as_of, asset_class enum, external_security_id, timestamps)
- [x] T016 [P] Create migration 008: `budget_envelopes` table (id, name, type enum [fixed/variable/rollover], rollover_cap decimal nullable, archived_at nullable, timestamps)
- [x] T017 [P] Create migration 009: `budget_months` table (id, budget_envelope_id FK, month integer, year integer, allocated_amount decimal, timestamps); unique index on (budget_envelope_id, month, year)
- [x] T018 [P] Create migration 010: `envelope_categories` table (id, budget_envelope_id FK, category_id FK, timestamps); unique index on category_id (one category → at most one active envelope)
- [x] T019 [P] Create migration 011: `sync_logs` table (id, institution_id FK, status enum, accounts_updated, transactions_added, transactions_modified, error_message, started_at, completed_at, timestamps)
- [x] T020 Create category seed data in `priv/repo/seeds.exs`: 12 top-level system categories (Income, Housing, Food & Drink, Transport, Shopping, Health, Entertainment, Utilities, Travel, Finance, Transfer, Uncategorized) with `is_system: true`
- [x] T021 Implement Phoenix authentication: `lib/xactions_web/live/auth/login_live.ex` (bcrypt password check), `lib/xactions_web/plugs/auth_plug.ex` (session guard), and `lib/xactions_web/router.ex` (authenticated pipeline wrapping all live routes)
- [x] T022 Create test support files: `test/support/conn_case.ex` (authenticated conn helper), `test/support/fixtures.ex` (factory helpers for all entities), `test/support/fake_scraper.ex` (implements `ScraperBehaviour` for tests)
- [x] T023 [P] Create OFX fixture files: `test/fixtures/ofx/checking_sample.ofx`, `test/fixtures/ofx/credit_card_sample.ofx`, `test/fixtures/ofx/brokerage_sample.ofx` (real or realistic OFX payloads covering all parsed element types)
- [x] T024 Create `lib/xactions_web/components/core_components.ex` with shared components: modal, flash, form field wrappers, error message (what/why/how format per constitution)

**Checkpoint**: `mix ecto.setup` completes; login page renders; `mix test` passes (no tests yet — baseline green).

---

## Phase 3: User Story 1 — Connect Financial Accounts (Priority: P1) 🎯 MVP

**Goal**: User can add an institution with credentials, trigger a sync via headless browser automation, and see account balances on the dashboard.

**Independent Test**: Add a manual institution, trigger a sync using the fake scraper, and confirm accounts + balances appear on the dashboard.

### Tests for User Story 1 ⚠️ Write first — confirm failing before T032

- [x] T025 [P] [US1] Write OFX parser unit tests in `test/xactions/sync/ofx_test.exs`: parse checking, credit card, and brokerage OFX fixtures; assert correct transaction counts, amounts, FITIDs, and balance values
- [x] T026 [P] [US1] Write CSV parser unit tests in `test/xactions/sync/csv_parser_test.exs`: parse sample CSV with institution column-map config; assert normalized transaction output
- [x] T027 [P] [US1] Write `Accounts` context integration tests in `test/xactions/accounts/accounts_test.exs`: create institution (with encrypted credentials), create manual account, list accounts, update institution status transitions
- [x] T028 [P] [US1] Write `SyncWorker` integration tests in `test/xactions/sync/sync_worker_test.exs`: use `FakeScraper` to simulate a successful sync, MFA pause, and credential error; assert `SyncLog` entries and account balance updates
- [x] T029 [US1] Write `AccountsLive` and `DashboardLive` LiveView tests in `test/xactions_web/live/accounts_live_test.exs` and `test/xactions_web/live/dashboard_live_test.exs`: add institution form, trigger sync, confirm accounts appear, confirm reconnect alert

### Implementation for User Story 1

- [x] T030 [P] [US1] Implement OFX parser in `lib/xactions/sync/ofx.ex`: parse OFX 1.x SGML and 2.x XML; extract `<STMTTRN>`, `<INVPOSLIST>`, `<LEDGERBAL>`; return structured `account_data`, `transaction_data`, `holding_data` maps
- [x] T031 [P] [US1] Implement CSV parser in `lib/xactions/sync/csv_parser.ex`: accept institution column-map config + NimbleCSV binary; return normalized `transaction_data` list
- [x] T032 [P] [US1] Implement `ScraperBehaviour` in `lib/xactions/sync/scraper_behaviour.ex`: define `@callback sync/2`, `@callback resolve_mfa/2`, `@callback name/0`, `@callback export_format/0`
- [x] T033 [P] [US1] Implement `Institution` schema in `lib/xactions/accounts/institution.ex`: Ecto schema with `Cloak.Ecto.Binary` for `credential_username`, `credential_password`, `totp_seed`, `session_cookies`; changeset with validations
- [x] T034 [P] [US1] Implement `Account` schema in `lib/xactions/accounts/account.ex`: Ecto schema with type enum, belongs_to institution, changeset
- [x] T035 [US1] Implement `Accounts` context in `lib/xactions/accounts/accounts.ex`: `list_institutions/0`, `get_institution!/1`, `create_institution/1`, `update_institution_status/2`, `disconnect_institution/1` (deletes institution + all accounts + all their transactions)
- [x] T036 [P] [US1] Implement `SyncLog` schema in `lib/xactions/sync/sync_log.ex`: Ecto schema with status enum, belongs_to institution
- [x] T037 [US1] Implement `SyncWorker` in `lib/xactions/sync/sync_worker.ex`: decrypt credentials, launch Playwright browser context, call scraper module, parse OFX/CSV output, upsert accounts + transactions, write SyncLog, broadcast PubSub events (`sync:status`)
- [x] T038 [US1] Implement `SyncScheduler` GenServer in `lib/xactions/sync/sync_scheduler.ex`: supervised, schedules per-institution syncs via `Process.send_after`; handles `{:sync_now, institution_id}` and `{:sync_all}` messages; manual trigger callable from LiveView
- [x] T039 [US1] Implement `MFACoordinator` GenServer in `lib/xactions/sync/mfa_coordinator.ex`: pauses a SyncWorker awaiting an MFA code; accepts `resolve_mfa/2` call from MfaLive; times out after 5 minutes with `:mfa_timeout` error
- [x] T040 [US1] Add `ConnectorSupervisor` and `MFACoordinator` to supervision tree in `lib/xactions/application.ex` alongside `SyncScheduler`
- [x] T041 [P] [US1] Implement example scraper stub in `lib/xactions/sync/scrapers/example_bank.ex` implementing `ScraperBehaviour` with inline documentation showing Playwright navigation pattern
- [x] T042 [US1] Implement `AccountsLive` in `lib/xactions_web/live/accounts_live.ex`: handles `add_institution`, `save_institution`, `edit_credentials`, `save_credentials`, `remove_institution` events per `contracts/liveview-events.md`; integrates Playwright Link flow via push event to JS hook
- [x] T043 [US1] Implement `MfaLive` component in `lib/xactions_web/live/mfa_live.ex`: subscribes to `sync:status` PubSub; shows MFA input modal on `:mfa_required`; handles `submit_mfa` and `dismiss_mfa` events
- [x] T044 [P] [US1] Implement `DashboardLive` (accounts panel) in `lib/xactions_web/live/dashboard_live.ex`: displays all accounts grouped by institution with balances; `sync_now` and `sync_all` events; subscribes to `sync:status` PubSub; shows reconnect alerts
- [x] T045 [P] [US1] Implement `AccountCard` component in `lib/xactions_web/components/account_card.ex` and `SyncStatusBadge` in `lib/xactions_web/components/sync_status_badge.ex`

**Checkpoint**: Manual institution creation, sync via FakeScraper, and account display all work end-to-end. `mix test test/xactions/sync/ test/xactions_web/live/accounts_live_test.exs` passes.

---

## Phase 4: User Story 2 — View and Categorize Transactions (Priority: P2)

**Goal**: User can view all transactions in a unified feed, filter them, change a category, split a transaction, and search by merchant name.

**Independent Test**: Add manual transactions to a manual account, verify they appear in the feed, change a category and confirm the merchant rule is created, and split a transaction with amounts that sum correctly.

### Tests for User Story 2 ⚠️ Write first — confirm failing before T051

- [x] T046 [P] [US2] Write `Transactions` context integration tests in `test/xactions/transactions/transactions_test.exs`: list transactions with filters, search by merchant, update category + merchant rule upsert, split transaction validation (amounts must sum), prevent split with mismatched total
- [x] T047 [US2] Write `TransactionsLive` LiveView tests in `test/xactions_web/live/transactions_live_test.exs`: filter by date range, category edit inline, split editor save/cancel, manual transaction add, load-more pagination

### Implementation for User Story 2

- [x] T048 [P] [US2] Implement `Category` schema in `lib/xactions/transactions/category.ex`: Ecto schema with parent_id self-reference, is_system flag, changeset (prevent deletion of system categories)
- [x] T049 [P] [US2] Implement `Transaction` schema in `lib/xactions/transactions/transaction.ex`: Ecto schema with category_id nullable when is_split true; changeset enforcing split/category mutual exclusivity
- [x] T050 [P] [US2] Implement `TransactionSplit` schema in `lib/xactions/transactions/transaction_split.ex`: changeset with split-sum validation against parent transaction amount
- [x] T051 [P] [US2] Implement `MerchantCategoryRule` schema in `lib/xactions/transactions/merchant_rule.ex`: upsert-friendly changeset; `normalize_merchant/1` helper (lowercase, strip trailing digits/punctuation)
- [x] T052 [US2] Implement `Transactions` context in `lib/xactions/transactions/transactions.ex`: `list_transactions/1` (filterable by account, category, date range, query), `search_transactions/1`, `update_category/2` (upserts merchant rule), `split_transaction/2` (validates sum), `add_manual_transaction/1`; auto-categorization via `MerchantCategoryRule` lookup on import
- [x] T053 [US2] Implement `TransactionsLive` in `lib/xactions_web/live/transactions_live.ex`: handles all events from `contracts/liveview-events.md`; 50-per-page cursor pagination; search debounced via Phoenix LiveView's `phx-debounce`
- [x] T054 [P] [US2] Implement `TransactionRow` component in `lib/xactions_web/components/transaction_row.ex` and `CategorySelect` in `lib/xactions_web/components/category_select.ex`

**Checkpoint**: Full transaction workflow (view, filter, search, categorize, split) works without sync. `mix test test/xactions/transactions/ test/xactions_web/live/transactions_live_test.exs` passes.

---

## Phase 5: User Story 3 — Investment Portfolio Overview (Priority: P3)

**Goal**: User can view all investment holdings with current value, cost basis, and gain/loss, plus an asset-class allocation chart.

**Independent Test**: Sync a brokerage OFX fixture with holdings data; verify holdings list, computed gain/loss, and allocation breakdown display correctly.

### Tests for User Story 3 ⚠️ Write first — confirm failing before T058

- [x] T055 [P] [US3] Write `Portfolio` context integration tests in `test/xactions/portfolio/portfolio_test.exs`: import brokerage OFX fixture, verify holding records, computed current_value/gain_loss, allocation percentages by asset class, stale-price display logic
- [x] T056 [US3] Write `PortfolioLive` LiveView tests in `test/xactions_web/live/portfolio_live_test.exs`: period selector updates chart data, price_as_of label present when data is stale

### Implementation for User Story 3

- [x] T057 [P] [US3] Implement `Holding` schema in `lib/xactions/portfolio/holding.ex`: Ecto schema with asset_class enum; computed fields `current_value`, `unrealized_gain_loss`, `unrealized_gain_loss_pct` as virtual fields populated in context queries
- [x] T058 [US3] Implement `Portfolio` context in `lib/xactions/portfolio/portfolio.ex`: `list_holdings/0` (with computed fields), `get_allocation/0` (grouped by asset_class with percentage), `replace_holdings_for_account/2` (delete-then-insert from OFX sync), `oldest_price_timestamp/0`
- [x] T059 [US3] Implement `PortfolioLive` in `lib/xactions_web/live/portfolio_live.ex`: handles `set_period` event; shows `price_as_of` banner when data is older than 15 minutes; allocation breakdown list
- [x] T060 [P] [US3] Implement `ChartComponent` in `lib/xactions_web/components/chart_component.ex`: server-rendered SVG or lightweight JS chart hook; used for portfolio performance and net worth history

**Checkpoint**: Brokerage OFX fixture imports correctly; portfolio page shows holdings, allocation, and price-as-of label. `mix test test/xactions/portfolio/ test/xactions_web/live/portfolio_live_test.exs` passes.

---

## Phase 6: User Story 4 — Zero-Based Budget Management (Priority: P4)

**Goal**: User can create envelopes (fixed/variable/rollover), assign categories, allocate real Income-category dollars via YNAB-style TBB, track envelope balances in real time, and see rollover caps enforced at month transition.

**Independent Test**: Create two envelopes with categories, add an Income transaction (TBB grows), allocate to envelopes until TBB reaches $0, add a spending transaction and confirm the correct envelope balance decreases in real time.

### Tests for User Story 4 ⚠️ Write first — confirm failing before T067

- [x] T061 [P] [US4] Write `Budgeting` context integration tests in `test/xactions/budgeting/budgeting_test.exs`:
  - TBB = sum of Income-category transactions minus sum of allocations
  - TBB updates when an Income transaction is added/removed
  - Fixed envelope carries same amount forward at month rollover
  - Variable envelope pre-fills previous month's budgeted amount
  - Rollover envelope accumulates unspent balance (cumulative carry-forward)
  - Rollover cap: surplus above cap returns to TBB, not envelope
  - Archived envelope excluded from rollover and active allocation
  - Category cannot be assigned to two active envelopes simultaneously
  - Envelope going negative (overspent) is allowed and stored
  - `list_unassigned_transactions/1` returns only transactions in categories not mapped to any active envelope
- [x] T062 [US4] Write `BudgetLive` LiveView tests in `test/xactions_web/live/budget_live_test.exs`: TBB indicator updates in real time via PubSub when a transaction arrives, envelope balance decreases on spending, unassigned spending section populates, archive envelope removes it from active view

### Implementation for User Story 4

- [x] T063 [P] [US4] Implement `BudgetEnvelope` schema in `lib/xactions/budgeting/budget_envelope.ex`: type enum (fixed/variable/rollover), `rollover_cap` nullable decimal, `archived_at` nullable datetime; changeset prevents deletion when budget_months exist
- [x] T064 [P] [US4] Implement `BudgetMonth` schema in `lib/xactions/budgeting/budget_month.ex`: belongs_to budget_envelope, month/year integers, allocated_amount decimal; unique constraint on (envelope_id, month, year)
- [x] T065 [P] [US4] Implement `EnvelopeCategory` schema in `lib/xactions/budgeting/envelope_category.ex`: belongs_to budget_envelope and category; unique index on category_id enforcing single-envelope-per-category rule
- [x] T066 [US4] Implement `Budgeting` context in `lib/xactions/budgeting/budgeting.ex`:
  - `calculate_tbb/1` — sum Income-category transactions for month minus sum of BudgetMonth allocations
  - `create_envelope/1`, `update_envelope/2`, `archive_envelope/1`
  - `assign_category_to_envelope/2`, `remove_category_from_envelope/2`
  - `set_allocation/3` — create or update BudgetMonth for envelope + month + year
  - `envelope_balance/2` — allocated minus spent (sum of transactions in assigned categories)
  - `list_unassigned_transactions/1` — transactions in categories not in any active envelope
  - `rollover_month/1` — creates next month's BudgetMonth rows per type rules; enforces cap for rollover envelopes; returns surplus to TBB
- [x] T067 [US4] Add month rollover trigger to `SyncScheduler` in `lib/xactions/sync/sync_scheduler.ex`: schedule `Budgeting.rollover_month/1` on the 1st of each month via `Process.send_after`; idempotent (skip if already rolled over)
- [x] T068 [US4] Implement `BudgetLive` in `lib/xactions_web/live/budget_live.ex`: shows TBB indicator, envelope list with budgeted/spent/remaining per envelope, unassigned spending section; handles `create_envelope`, `archive_envelope`, `set_allocation`, `assign_category` events; subscribes to transaction PubSub to update balances in real time
- [x] T069 [P] [US4] Implement `TBBIndicator` component in `lib/xactions_web/components/tbb_indicator.ex`: prominently shows TBB with colour coding (green = $0, amber = positive, red = negative/over-allocated)
- [x] T070 [P] [US4] Implement `BudgetEnvelopeCard` component in `lib/xactions_web/components/budget_envelope_card.ex`: shows envelope name, type badge, allocated/spent/remaining amounts, progress bar; highlights over-budget state

**Checkpoint**: Full ZBB workflow works: envelopes created, categories assigned, Income transaction grows TBB, allocation reduces TBB to $0, spending reduces envelope in real time, month rollover produces correct carry-forward per type. `mix test test/xactions/budgeting/ test/xactions_web/live/budget_live_test.exs` passes.

---

## Phase 7: User Story 5 — Net Worth Dashboard and Spending Reports (Priority: P5)

**Goal**: User sees net worth tracked over time, monthly spending by envelope, month-over-month comparison, and a budget history grid.

**Independent Test**: With several months of transaction data, verify net worth is computed correctly, the envelope spending report matches transaction totals, and the month-over-month delta is accurate.

### Tests for User Story 5 ⚠️ Write first — confirm failing before T074

- [x] T071 [P] [US5] Write `Reporting` context integration tests in `test/xactions/reporting/reporting_test.exs`: net worth = assets - liabilities; spending_by_envelope sums transactions in assigned categories; month-over-month delta is correct; budget history grid returns correct (month × envelope) matrix
- [x] T072 [US5] Write `ReportsLive` and `DashboardLive` (net worth panel) tests in `test/xactions_web/live/reports_live_test.exs`: select month changes data, drill into envelope shows transactions, net worth history chart renders

### Implementation for User Story 5

- [x] T073 [US5] Implement `Reporting` context in `lib/xactions/reporting/reporting.ex`:
  - `net_worth/0` — sum of all asset account balances minus all liability account balances
  - `net_worth_history/1` — monthly net worth for trailing N months
  - `spending_by_envelope/2` — for a given month/year, spending per envelope
  - `month_over_month/2` — compare two months by envelope (delta + pct)
  - `budget_history_grid/0` — (month × envelope) matrix of allocated and spent amounts
- [x] T074 [US5] Implement `ReportsLive` in `lib/xactions_web/live/reports_live.ex`: handles `select_month`, `set_budget` (delegates to Budgeting context), `clear_budget` events; budget history grid with drill-down to transactions; month-over-month comparison table
- [x] T075 [US5] Update `DashboardLive` in `lib/xactions_web/live/dashboard_live.ex` to add net worth panel: total assets, total liabilities, net worth figure, month-over-month change using `Reporting.net_worth/0`
- [x] T076 [P] [US5] Implement `NetWorthWidget` component in `lib/xactions_web/components/net_worth_widget.ex`: renders net worth with month-over-month delta and directional indicator

**Checkpoint**: Net worth dashboard, spending-by-envelope report, month-over-month table, and budget history grid all render correctly. `mix test test/xactions/reporting/ test/xactions_web/live/reports_live_test.exs` passes.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Non-story-specific improvements affecting all phases.

- [x] T077 [P] Add sync failure alert: if a `SyncLog` error entry is older than 1 hour and unacknowledged, broadcast a PubSub alert to `DashboardLive` in `lib/xactions/sync/sync_scheduler.ex` (hourly check via `Process.send_after`)
- [x] T078 [P] Implement pending transaction settlement: in `SyncWorker`, when an incoming transaction has the same `fit_id` as an existing `is_pending: true` row, update the amount and clear `is_pending` rather than inserting a duplicate
- [x] T079 [P] Add database indexes: verify all indexes from `data-model.md` are present in migrations; add a migration for any missing (transactions date DESC, merchant_name, holdings account+symbol)
- [x] T080 [P] Performance benchmark task: add `test/xactions/performance_test.exs` with ExUnit benchmarks asserting dashboard load < 2s p95 and transaction search < 500ms p95 against a 50k-row SQLite fixture
- [x] T081 Run quickstart validation checklist from `specs/001-personal-accounting/quickstart.md` end-to-end in Docker; document any deviations
- [x] T082 [P] Add `mix hex.audit` to CI and pin all deps in `mix.lock`; document in `CLAUDE.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Requires Phase 1 completion — blocks all user stories
- **US1 (Phase 3)**: Requires Foundational — no dependency on US2–US5
- **US2 (Phase 4)**: Requires Foundational + categories seeded — no dependency on US1
- **US3 (Phase 5)**: Requires Foundational + US1 (SyncWorker for OFX import) — no dependency on US2/US4/US5
- **US4 (Phase 6)**: Requires Foundational + US2 (categories, transactions) — no dependency on US1/US3
- **US5 (Phase 7)**: Requires US4 (envelopes for spending-by-envelope) + US2 (transactions) — no dependency on US1/US3
- **Polish (Phase 8)**: Requires all desired user stories complete

### Parallel Opportunities Within Each Phase

**Phase 2 (Foundational)**: T009–T019 (all migrations) can be written in parallel; T008 (vault), T020 (seeds), T021 (auth), T022 (test support) can also proceed in parallel with migrations.

**Phase 3 (US1)**:
```
Parallel group A (write tests first): T025, T026, T027, T028, T029
Parallel group B (after tests fail): T030 (OFX), T031 (CSV), T032 (Behaviour), T033 (Institution schema), T034 (Account schema)
Sequential: T035 (Accounts context) → T036 (SyncLog) → T037 (SyncWorker) → T038 (SyncScheduler) → T039 (MFACoordinator)
Parallel group C: T041 (example scraper), T042 (AccountsLive), T043 (MfaLive), T044 (DashboardLive), T045 (components)
```

**Phase 4 (US2)**: T046–T047 (tests) → T048–T051 (schemas, parallel) → T052 (context) → T053 (LiveView) → T054 (components, parallel)

**Phase 6 (US4)**: T061–T062 (tests) → T063–T065 (schemas, parallel) → T066 (context) → T067 (rollover trigger) → T068 (BudgetLive) → T069–T070 (components, parallel)

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories)
3. Complete Phase 3: US1 (account connection + sync)
4. **STOP and VALIDATE**: Manual sync works with real institution, accounts and transactions appear
5. Demo / daily-drive before proceeding

### Incremental Delivery

1. Phase 1 + 2 → Foundation ready
2. Phase 3 (US1) → Sync working → validate independently
3. Phase 4 (US2) → Transaction categorization → validate independently
4. Phase 6 (US4) → Zero-based budgeting → validate independently *(can run in parallel with US2 once Foundational is done)*
5. Phase 5 (US3) → Portfolio view → validate independently
6. Phase 7 (US5) → Reporting → validate independently
7. Phase 8 → Polish → production-ready

### Parallel Team Strategy

With two developers after Foundational is complete:
- **Dev A**: US1 (sync + accounts) → US3 (portfolio)
- **Dev B**: US2 (transactions) → US4 (ZBB budgeting) → US5 (reports)

---

## Task Summary

| Phase | Tasks | Parallel | Story |
|-------|-------|----------|-------|
| Setup | T001–T007 | 5 of 7 | — |
| Foundational | T008–T024 | 13 of 17 | — |
| US1 Connect | T025–T045 | 10 of 21 | US1 |
| US2 Transactions | T046–T054 | 5 of 9 | US2 |
| US3 Portfolio | T055–T060 | 3 of 6 | US3 |
| US4 ZBB Budget | T061–T070 | 5 of 10 | US4 |
| US5 Reports | T071–T076 | 2 of 6 | US5 |
| Polish | T077–T082 | 5 of 6 | — |
| **Total** | **82** | **48** | |

**Notes**:
- Tasks marked `[P]` = different files, no incomplete-task dependencies, safe to run in parallel
- All `[Story]` tasks MUST have their tests written and confirmed failing first (constitution Principle II)
- `mix test` must stay green between each task or logical group
- Commit after each task or logical group of parallel tasks
