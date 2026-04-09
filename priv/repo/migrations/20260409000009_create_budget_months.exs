defmodule Xactions.Repo.Migrations.CreateBudgetMonths do
  use Ecto.Migration

  def change do
    create table(:budget_months) do
      add :budget_envelope_id, references(:budget_envelopes, on_delete: :delete_all), null: false
      add :month, :integer, null: false
      add :year, :integer, null: false
      add :allocated_amount, :decimal, precision: 15, scale: 2, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:budget_months, [:budget_envelope_id, :month, :year])
    create index(:budget_months, [:year, :month])
  end
end
