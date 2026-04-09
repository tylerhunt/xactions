# Stage 1: Build
FROM elixir:1.19.5-otp-27-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git nodejs npm \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=prod

COPY mix.exs mix.lock ./
RUN mix local.hex --force && mix local.rebar --force
RUN mix deps.get --only prod
RUN mix deps.compile

COPY assets assets
COPY config config
COPY lib lib
COPY priv priv

RUN mix assets.deploy
RUN mix compile
RUN mix release

# Stage 2: Runtime (Playwright base for headless browser support)
FROM mcr.microsoft.com/playwright:v1.52.0-jammy AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 libncurses6 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /app/_build/prod/rel/xactions ./

RUN mkdir -p /app/data

ENV PHX_SERVER=true
ENV MIX_ENV=prod

EXPOSE 4000

CMD ["/app/bin/xactions", "start"]
