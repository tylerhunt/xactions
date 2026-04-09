defmodule Xactions.Repo.Migrations.CreateAccounts do
  use Ecto.Migration

  def change do
    create table(:accounts) do
      add :institution_id, references(:institutions, on_delete: :delete_all)
      add :name, :string, null: false
      add :type, :string, null: false
      add :balance, :decimal, precision: 15, scale: 2, default: 0
      add :currency, :string, default: "USD", null: false
      add :external_account_id, :string
      add :is_manual, :boolean, default: false, null: false
      add :is_active, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:accounts, [:institution_id])
    create index(:accounts, [:type])
  end
end
