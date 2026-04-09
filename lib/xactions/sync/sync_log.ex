defmodule Xactions.Sync.SyncLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sync_logs" do
    field :status, :string
    field :accounts_updated, :integer, default: 0
    field :transactions_added, :integer, default: 0
    field :transactions_modified, :integer, default: 0
    field :error_message, :string
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime

    belongs_to :institution, Xactions.Accounts.Institution

    timestamps(type: :utc_datetime)
  end

  @valid_statuses ~w(running success partial_success error mfa_required)

  def changeset(sync_log, attrs) do
    sync_log
    |> cast(attrs, [
      :institution_id,
      :status,
      :accounts_updated,
      :transactions_added,
      :transactions_modified,
      :error_message,
      :started_at,
      :completed_at
    ])
    |> validate_required([:institution_id, :status])
    |> validate_inclusion(:status, @valid_statuses)
    |> foreign_key_constraint(:institution_id)
  end
end
