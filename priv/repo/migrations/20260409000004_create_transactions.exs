defmodule Xactions.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :category_id, references(:categories, on_delete: :nilify_all)
      add :date, :date, null: false
      add :amount, :decimal, precision: 15, scale: 2, null: false
      add :merchant_name, :string
      add :raw_merchant, :string
      add :fit_id, :string
      add :notes, :text
      add :is_pending, :boolean, default: false, null: false
      add :is_split, :boolean, default: false, null: false
      add :is_manual, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:transactions, [:account_id])
    create index(:transactions, [:category_id])
    create index(:transactions, [:date])
    create index(:transactions, [:merchant_name])
    create unique_index(:transactions, [:account_id, :fit_id],
      where: "fit_id IS NOT NULL",
      name: :transactions_account_id_fit_id_index
    )
  end
end
