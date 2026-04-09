defmodule Xactions.Transactions.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transactions" do
    field :date, :date
    field :amount, :decimal
    field :merchant_name, :string
    field :raw_merchant, :string
    field :fit_id, :string
    field :notes, :string
    field :is_pending, :boolean, default: false
    field :is_split, :boolean, default: false
    field :is_manual, :boolean, default: false

    belongs_to :account, Xactions.Accounts.Account
    belongs_to :category, Xactions.Transactions.Category
    has_many :splits, Xactions.Transactions.TransactionSplit

    timestamps(type: :utc_datetime)
  end

  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [
      :account_id,
      :category_id,
      :date,
      :amount,
      :merchant_name,
      :raw_merchant,
      :fit_id,
      :notes,
      :is_pending,
      :is_split,
      :is_manual
    ])
    |> validate_required([:account_id, :date, :amount])
    |> foreign_key_constraint(:account_id)
    |> foreign_key_constraint(:category_id)
    |> validate_split_category_exclusivity()
  end

  defp validate_split_category_exclusivity(changeset) do
    is_split = get_field(changeset, :is_split)
    category_id = get_field(changeset, :category_id)

    if is_split && category_id do
      add_error(changeset, :category_id, "cannot set category on a split transaction")
    else
      changeset
    end
  end
end
