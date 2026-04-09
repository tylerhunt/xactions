defmodule Xactions.Transactions.TransactionSplit do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transaction_splits" do
    field :amount, :decimal
    field :notes, :string

    belongs_to :transaction, Xactions.Transactions.Transaction
    belongs_to :category, Xactions.Transactions.Category

    timestamps(type: :utc_datetime)
  end

  def changeset(split, attrs) do
    split
    |> cast(attrs, [:transaction_id, :category_id, :amount, :notes])
    |> validate_required([:transaction_id, :category_id, :amount])
    |> foreign_key_constraint(:transaction_id)
    |> foreign_key_constraint(:category_id)
  end
end
