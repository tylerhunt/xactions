defmodule Xactions.Repo.Migrations.CreateHoldings do
  use Ecto.Migration

  def change do
    create table(:holdings) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :symbol, :string, null: false
      add :name, :string
      add :quantity, :decimal, precision: 20, scale: 8, null: false
      add :cost_basis, :decimal, precision: 15, scale: 2
      add :current_price, :decimal, precision: 15, scale: 4
      add :price_as_of, :utc_datetime
      add :asset_class, :string, null: false, default: "equity"
      add :external_security_id, :string

      timestamps(type: :utc_datetime)
    end

    create index(:holdings, [:account_id])
    create unique_index(:holdings, [:account_id, :symbol])
  end
end
