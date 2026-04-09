# Quickstart: xactions

Personal accounting application with automated bank sync via headless browser
automation (Playwright) and OFX/CSV export parsing.

## Prerequisites

- Elixir ~> 1.17 and Erlang/OTP 27
- Node.js ~> 20 (for Playwright server and asset compilation)
- Docker + Docker Compose (for homelab deployment)
- Playwright browsers installed (see below)

---

## Local Development

### 1. Clone and install dependencies

```bash
git clone <repo-url> xactions
cd xactions
mix setup          # deps.get + ecto.setup + assets.setup
```

### 2. Install Playwright and browsers

```bash
# Install the Playwright Node.js package (used by playwright-elixir)
npm install --prefix assets playwright

# Install Chromium browser
npx --prefix assets playwright install chromium
```

### 3. Configure environment

```bash
cp .env.example .env
```

Required variables:

```bash
# Phoenix
SECRET_KEY_BASE=<64-char hex — generate with: mix phx.gen.secret>
PHX_HOST=localhost
PORT=4000

# Database
DATABASE_PATH=./priv/repo/xactions.db

# Encryption key for bank credentials (AES-256-GCM)
# Generate with:
#   32 |> :crypto.strong_rand_bytes() |> Base.encode64() |> IO.puts()
CLOAK_KEY=<base64-encoded-256-bit-key>

# Playwright server (started automatically by the app)
PLAYWRIGHT_SERVER_PORT=3000
```

### 4. Start the development server

```bash
mix phx.server
```

Open `http://localhost:4000`.

### 5. Add your first institution

1. Navigate to **Accounts → Add Institution**.
2. Select the institution type and enter your login credentials.
3. If your institution supports OFX Direct Connect, toggle that option and enter
   the OFX server details.
4. Click **Sync Now** to trigger the first sync. Playwright will open a headless
   browser, log in, and download your transaction export.
5. If MFA is required, the app will prompt you to enter the code.

---

## Adding a New Institution Scraper

Each institution requires a dedicated scraper module:

```elixir
defmodule Xactions.Sync.Scrapers.MyBank do
  @behaviour Xactions.Sync.ScraperBehaviour

  @impl true
  def name(), do: "My Bank"

  @impl true
  def export_format(), do: :ofx

  @impl true
  def sync(institution, browser_context) do
    # 1. Navigate to login page
    # 2. Enter credentials
    # 3. Handle MFA if required
    # 4. Navigate to export/download section
    # 5. Download OFX file
    # 6. Parse and return structured data
  end

  @impl true
  def resolve_mfa(browser_context, code) do
    # Submit the MFA code to the waiting browser session
  end
end
```

Register the module in `config/config.exs`:

```elixir
config :xactions, :scrapers, [
  Xactions.Sync.Scrapers.MyBank,
  # ...
]
```

---

## Running Tests

```bash
# All tests
mix test

# Unit + integration tests (no browser)
mix test --exclude browser

# Scraper contract tests (requires Playwright + institution test credentials)
mix test test/xactions/sync/ --include browser

# With coverage
mix test --cover
```

Tests use an in-memory SQLite database. Integration tests run against real SQLite —
no mocks for the database layer.

---

## Docker Deployment (Homelab)

### 1. Generate production secrets

```bash
mix phx.gen.secret
# Copy output → SECRET_KEY_BASE

32 |> :crypto.strong_rand_bytes() |> Base.encode64() |> IO.puts()
# Copy output → CLOAK_KEY
```

### 2. Configure Docker Compose

```yaml
services:
  xactions:
    image: xactions:latest
    build: .
    restart: unless-stopped
    volumes:
      - ./data:/app/data          # SQLite database
    environment:
      SECRET_KEY_BASE: "${SECRET_KEY_BASE}"
      PHX_HOST: "xactions.yourdomain.local"
      DATABASE_PATH: "/app/data/xactions.db"
      CLOAK_KEY: "${CLOAK_KEY}"
      PLAYWRIGHT_SERVER_PORT: "3000"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.xactions.rule=Host(`xactions.yourdomain.local`)"
      - "traefik.http.routers.xactions.entrypoints=websecure"
      - "traefik.http.routers.xactions.tls=true"
      - "traefik.http.services.xactions.loadbalancer.server.port=4000"
    networks:
      - traefik_proxy

networks:
  traefik_proxy:
    external: true
```

Store secrets in `.env` alongside `docker-compose.yml` (never commit this file):

```bash
SECRET_KEY_BASE=...
CLOAK_KEY=...
```

### 3. Build and start

```bash
docker compose build

docker compose up -d

# Run migrations on first start
docker compose exec xactions bin/xactions eval "Xactions.Release.migrate()"

docker compose logs -f xactions
```

### Note on Docker image size

The Docker image includes Playwright's Chromium browser (~300MB). The Dockerfile
uses a multi-stage build:

- **Build stage**: Elixir/OTP image compiles the release and assets.
- **Runtime stage**: Playwright base image (`mcr.microsoft.com/playwright`) provides
  the browser; the Elixir release is copied in.

---

## Backup

All state lives in `./data/xactions.db`. SQLite WAL mode allows safe live backup:

```bash
# Manual backup
cp ./data/xactions.db ./data/xactions-$(date +%Y%m%d).db

# Automated daily backup (host crontab)
0 2 * * * sqlite3 /path/to/data/xactions.db ".backup /path/to/backups/xactions-$(date +\%Y\%m\%d).db"
```

---

## Validation Checklist

After first deployment:

- [ ] App loads at configured hostname over HTTPS
- [ ] Can add an institution with credentials
- [ ] Manual sync completes and shows accounts + transactions
- [ ] Category override persists after page reload
- [ ] Net worth dashboard shows correct total
- [ ] Split transaction amounts sum to parent amount
- [ ] MFA prompt appears when institution requires it
- [ ] SQLite database file persists across container restarts
