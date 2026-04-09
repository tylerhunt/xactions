defmodule Xactions.Repo.Migrations.CreateSyncLogs do
  use Ecto.Migration

  def change do
    create table(:sync_logs) do
      add :institution_id, references(:institutions, on_delete: :delete_all), null: false
      add :status, :string, null: false
      add :accounts_updated, :integer, default: 0
      add :transactions_added, :integer, default: 0
      add :transactions_modified, :integer, default: 0
      add :error_message, :text
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:sync_logs, [:institution_id])
    create index(:sync_logs, [:status])
    create index(:sync_logs, [:started_at])
  end
end
