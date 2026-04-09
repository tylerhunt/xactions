defmodule Xactions.Repo.Migrations.CreateBudgetEnvelopes do
  use Ecto.Migration

  def change do
    create table(:budget_envelopes) do
      add :name, :string, null: false
      add :type, :string, null: false
      add :rollover_cap, :decimal, precision: 15, scale: 2
      add :archived_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end
  end
end
