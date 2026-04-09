defmodule Xactions.Repo.Migrations.CreateMerchantCategoryRules do
  use Ecto.Migration

  def change do
    create table(:merchant_category_rules) do
      add :merchant_pattern, :string, null: false
      add :category_id, references(:categories, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:merchant_category_rules, [:merchant_pattern])
    create index(:merchant_category_rules, [:category_id])
  end
end
