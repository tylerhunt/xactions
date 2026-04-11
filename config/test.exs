import Config

config :xactions, Xactions.Vault,
  ciphers: [
    default:
      {Cloak.Ciphers.AES.GCM,
       tag: "AES.GCM.V1",
       key: Base.decode64!("w9T0vedKm9QKc1N5AzBKaRgJPVoNLs/Zy+7DY5xdIV0="),
       iv_length: 12}
  ]

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :xactions, Xactions.Repo,
  database: Path.expand("../priv/repo/test#{System.get_env("MIX_TEST_PARTITION")}.db",
    Path.dirname(__ENV__.file)),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :xactions, XactionsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "Z4v93KJNbN94zF5N9+xF7xWvhA78f3o1AsNC9N8qNXCIL51cKVAFWfhfVtLlmoSH",
  server: false

config :xactions, start_sync_scheduler: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
