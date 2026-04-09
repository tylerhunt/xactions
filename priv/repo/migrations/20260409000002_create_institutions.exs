defmodule Xactions.Repo.Migrations.CreateInstitutions do
  use Ecto.Migration

  def change do
    create table(:institutions) do
      add :name, :string, null: false
      add :website_url, :string
      add :scraper_module, :string
      add :sync_method, :string, null: false, default: "browser"
      add :ofx_direct_url, :string
      add :export_format, :string
      add :credential_username, :binary
      add :credential_password, :binary
      add :totp_seed, :binary
      add :session_cookies, :binary
      add :status, :string, null: false, default: "active"
      add :last_synced_at, :utc_datetime
      add :sync_interval_hours, :integer, default: 12
      add :is_manual_only, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
