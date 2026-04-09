defmodule Xactions.Repo.Migrations.CreateTransactionSplits do
  use Ecto.Migration

  def change do
    create table(:transaction_splits) do
      add :transaction_id, references(:transactions, on_delete: :delete_all), null: false
      add :category_id, references(:categories, on_delete: :restrict), null: false
      add :amount, :decimal, precision: 15, scale: 2, null: false
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:transaction_splits, [:transaction_id])
    create index(:transaction_splits, [:category_id])
  end
end
