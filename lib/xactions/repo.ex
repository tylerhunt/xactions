defmodule Xactions.Repo do
  use Ecto.Repo,
    otp_app: :xactions,
    adapter: Ecto.Adapters.SQLite3
end
