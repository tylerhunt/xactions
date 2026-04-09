defmodule Xactions.Repo.Migrations.CreateEnvelopeCategories do
  use Ecto.Migration

  def change do
    create table(:envelope_categories) do
      add :budget_envelope_id, references(:budget_envelopes, on_delete: :delete_all), null: false
      add :category_id, references(:categories, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:envelope_categories, [:category_id])
    create index(:envelope_categories, [:budget_envelope_id])
  end
end
