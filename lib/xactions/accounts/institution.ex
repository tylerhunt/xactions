defmodule Xactions.Accounts.Institution do
  use Ecto.Schema
  import Ecto.Changeset

  schema "institutions" do
    field :name, :string
    field :website_url, :string
    field :scraper_module, :string
    field :sync_method, :string, default: "browser"
    field :ofx_direct_url, :string
    field :export_format, :string
    field :credential_username, Xactions.Encrypted.Binary
    field :credential_password, Xactions.Encrypted.Binary
    field :totp_seed, Xactions.Encrypted.Binary
    field :session_cookies, Xactions.Encrypted.Binary
    field :status, :string, default: "active"
    field :last_synced_at, :utc_datetime
    field :sync_interval_hours, :integer, default: 12
    field :is_manual_only, :boolean, default: false

    has_many :accounts, Xactions.Accounts.Account
    has_many :sync_logs, Xactions.Sync.SyncLog

    timestamps(type: :utc_datetime)
  end

  @valid_sync_methods ~w(browser ofx_direct manual)
  @valid_statuses ~w(active syncing mfa_required credential_error error inactive)

  def changeset(institution, attrs) do
    institution
    |> cast(attrs, [
      :name,
      :website_url,
      :scraper_module,
      :sync_method,
      :ofx_direct_url,
      :export_format,
      :credential_username,
      :credential_password,
      :totp_seed,
      :session_cookies,
      :status,
      :last_synced_at,
      :sync_interval_hours,
      :is_manual_only
    ])
    |> validate_required([:name, :sync_method, :status])
    |> validate_inclusion(:sync_method, @valid_sync_methods)
    |> validate_inclusion(:status, @valid_statuses)
  end

  def status_changeset(institution, status) when status in @valid_statuses do
    change(institution, status: status)
  end
end
