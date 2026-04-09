# Research: Personal Accounting with Multi-Institution Sync

**Branch**: `001-personal-accounting` | **Date**: 2026-04-09

## Financial Data Sync Strategy

**Decision**: Headless browser automation (Playwright) to log into each bank's website
and download transaction/holdings exports (OFX, QFX, CSV, or OFX/SGML depending on
the institution). No third-party financial aggregator API.

**Rationale**: Fully self-hosted with zero ongoing API costs or external dependencies.
The app stores and uses the user's bank credentials directly. Each institution gets
a dedicated "scraper module" that knows how to navigate that bank's web UI, trigger
an export, and retrieve the file. When a bank changes its UI, only the relevant scraper
module needs updating.

**Export format priority per institution** (tried in order):
1. **OFX/QFX** — structured, machine-readable, well-defined schema; preferred when
   offered (most major US banks offer OFX download from the activity export page).
2. **CSV** — common fallback; requires per-institution column mapping since there is no
   standard schema.
3. **PDF** — not supported in v1; requires OCR which is out of scope.

**Trade-offs accepted**:
- Bank website changes can break scrapers; each scraper module must be independently
  updatable.
- 2FA / MFA flows may interrupt automation; v1 handles TOTP-based 2FA automatically
  (if seed is provided) and notifies the user for SMS/push-based MFA.
- Headless browser overhead per sync: ~5–30 seconds per institution depending on page
  load times.

**Alternatives considered**:
- **Plaid / Finicity / MX**: Third-party aggregators. Rejected — user requires a
  fully self-hosted solution with no external API dependencies or per-transaction fees.
- **Direct OFX server connections (OFX Direct Connect)**: Some institutions expose an
  OFX server endpoint that accepts username/password over HTTPS without a browser.
  This is a faster, more reliable path where supported. Scrapers should try
  OFX Direct Connect first and fall back to browser automation. Documented as a
  per-institution option in the scraper module interface.

---

## Playwright Integration in Elixir

**Decision**: Use `playwright-elixir` (the `playwright` hex package) to drive a
Playwright browser server from Elixir.

**Rationale**: `playwright-elixir` provides Elixir API bindings that communicate with
the Playwright server (Node.js) over a local WebSocket connection. This keeps all
orchestration logic in Elixir (GenServer-based sync workers) while leveraging
Playwright's mature browser automation for the actual navigation. The Playwright server
runs as a sidecar process started by the application supervisor.

**Browser**: Chromium (headless). Bundled with the Playwright Node.js package.

**Docker consideration**: The Docker image must include Node.js and Playwright's
Chromium. Use the official `mcr.microsoft.com/playwright` base image (includes all
Playwright browsers) with Elixir installed on top, or use a multi-stage build.

**Alternatives considered**:
- **Elixir Port to a standalone Node.js Playwright script**: Viable but creates a
  tighter coupling between the scraper scripts and the Elixir process lifecycle.
  `playwright-elixir` is cleaner.
- **Wallaby / Hound**: Elixir browser testing libraries. Both use WebDriver/Selenium
  protocol. Playwright is faster, more reliable for modern web apps, and has better
  headless support.
- **Puppeteer via Elixir Port**: Similar to above; Playwright supersedes Puppeteer.

---

## OFX File Parsing

**Decision**: Implement an OFX parser as an internal Elixir module (`Xactions.Sync.OFX`).
No external parsing library.

**Rationale**: OFX 1.x (the format most banks export) is SGML-based, not valid XML,
but its transaction data follows a predictable tagged structure. A focused internal
parser for the subset of OFX elements needed (account info, transactions, balances)
is ~150 lines and has no dependencies. OFX 2.x (XML-based) can be parsed with the
standard `:xmerl` Erlang module.

**OFX elements parsed**:
- `<STMTRS>` — bank statement response (checking, savings, credit cards)
- `<INVSTMTRS>` — investment statement response (brokerages)
- `<STMTTRN>` — individual transaction
- `<INVPOSLIST>` — investment holdings
- `<LEDGERBAL>` / `<AVAILBAL>` — balances

**CSV fallback**: A per-institution column-mapping config maps CSV headers to the
standard transaction fields (date, amount, merchant, type). CSV parsers use
`NimbleCSV` (already a common Phoenix dependency or trivially added).

---

## Credential Encryption

**Decision**: Use `cloak_ecto` (AES-256-GCM) for field-level encryption of bank
usernames, passwords, TOTP seeds, and any session cookies stored in SQLite.

**Rationale**: The app now stores actual bank login credentials — this is the highest-
sensitivity data in the system and MUST be encrypted at rest. AES-256-GCM is
authenticated encryption (detects tampering). `cloak_ecto` provides transparent
field-level encryption in Ecto schemas with minimal boilerplate. The encryption key
lives in the environment (`CLOAK_KEY`) and is never written to the database.

**Encrypted fields**:
- `Institution.credential_username`
- `Institution.credential_password`
- `Institution.totp_seed` (optional — for TOTP-based 2FA)
- `Institution.session_cookies` (optional — cached session to reduce full login frequency)

**Key management**: Single AES-256-GCM key provided via `CLOAK_KEY` env var (base64-
encoded 32 bytes). Key rotation is out of v1 scope but supported by Cloak's key
version tagging.

**Alternatives considered**:
- **SQLite Encryption Extension (SEE)**: Full database file encryption. Rejected: paid
  license / custom SQLite build required; unavailable in standard Docker images.
- **Manual `:crypto` calls**: Viable but error-prone and harder to audit than
  `cloak_ecto`. Rejected.

---

## Background Sync Scheduler

**Decision**: Supervised `GenServer` with `Process.send_after/3` for scheduling
periodic syncs. No external job queue.

**Rationale**: Single-user app with infrequent, predictable sync events (daily per
institution). A `GenServer` self-scheduling via `Process.send_after` is zero-dependency
and sufficient. Browser automation adds latency (~5–30s per institution), so syncs run
sequentially per institution within the worker to avoid hammering a bank's site.

**Sync flow**:
1. `SyncScheduler` GenServer starts under application supervisor.
2. On init, checks `sync_logs` for each institution's last sync. Schedules next sync
   for each institution individually (respecting per-institution intervals).
3. On trigger (scheduled or manual), calls `SyncWorker.sync(institution)`:
   a. Launches Playwright browser session.
   b. Logs into institution website using decrypted credentials.
   c. Navigates to export/download section.
   d. Downloads OFX or CSV file.
   e. Parses and upserts transactions + balances into the database.
   f. Closes browser session.
   g. Writes `SyncLog` entry.
4. Manual sync trigger from UI sends `{:sync_now, institution_id}` to the GenServer.

**MFA handling**:
- **TOTP (e.g., Google Authenticator)**: If a TOTP seed is stored, the scraper
  generates the current TOTP code and enters it automatically.
- **SMS / push MFA**: The scraper detects the MFA challenge page and pauses. The app
  notifies the user via the UI (LiveView PubSub). The user enters the code in the app;
  the GenServer sends it to the waiting browser session.

---

## SQLite Adapter and Configuration

**Decision**: `ecto_sqlite3` with WAL mode and Docker volume persistence.

**Rationale**: Maintains all decisions from initial research. WAL mode is essential
here because browser sync workers write transactions while the LiveView layer reads
concurrently.

**SQLite pragmas**:
- `PRAGMA journal_mode=WAL`
- `PRAGMA foreign_keys=ON`
- `PRAGMA busy_timeout=5000`
- `PRAGMA synchronous=NORMAL`

---

## HTTP Client

**Decision**: `Req` (~> 0.5) for any direct HTTP calls (OFX Direct Connect where
supported, any institution-specific JSON APIs).

**Rationale**: Unchanged from original decision. Playwright handles browser-based
navigation; Req handles cases where OFX Direct Connect is available (no browser
needed), saving significant sync time for those institutions.

---

## Authentication (Single User)

**Decision**: Standard Phoenix session-based auth with `bcrypt_elixir`.

**Rationale**: Unchanged. Single user, homelab, no OAuth needed.

**Additional note**: The app login password is separate from all bank credentials.
Bank credentials are stored encrypted in SQLite; the app password is hashed with
bcrypt and stored separately.

---

## Docker Deployment

**Decision**: Single Docker container. Base image must include Playwright's browser
dependencies.

**Build approach**:
```dockerfile
# Multi-stage: build Elixir release on standard Elixir image
# Runtime: use Playwright base image + install Erlang runtime
FROM mcr.microsoft.com/playwright:v1.48.0-noble AS runtime-base
# Install Erlang/OTP (no build tools needed in runtime)
RUN apt-get install -y erlang-base ...
```

**Volumes**: `./data:/app/data` (SQLite database). No other persistent state.

**Traefik labels**: Applied in `docker-compose.yml` (TLS termination at Traefik).

**Alternatives considered**:
- **Separate browser sidecar container**: Run Playwright server in a separate
  container, connect from the Elixir app. Rejected: adds orchestration complexity;
  single container is simpler for a homelab.
