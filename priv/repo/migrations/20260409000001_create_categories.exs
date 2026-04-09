defmodule Xactions.Repo.Migrations.CreateCategories do
  use Ecto.Migration

  def change do
    create table(:categories) do
      add :name, :string, null: false
      add :icon, :string
      add :parent_id, references(:categories, on_delete: :restrict)
      add :is_system, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:categories, [:parent_id])
    create unique_index(:categories, [:name, :parent_id])
  end
end
