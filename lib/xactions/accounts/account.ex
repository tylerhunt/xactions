defmodule Xactions.Accounts.Account do
  use Ecto.Schema
  import Ecto.Changeset

  schema "accounts" do
    field :name, :string
    field :type, :string
    field :balance, :decimal, default: Decimal.new("0.00")
    field :currency, :string, default: "USD"
    field :external_account_id, :string
    field :is_manual, :boolean, default: false
    field :is_active, :boolean, default: true

    belongs_to :institution, Xactions.Accounts.Institution
    has_many :transactions, Xactions.Transactions.Transaction
    has_many :holdings, Xactions.Portfolio.Holding

    timestamps(type: :utc_datetime)
  end

  @valid_types ~w(checking savings credit_card loan mortgage brokerage)

  def changeset(account, attrs) do
    account
    |> cast(attrs, [
      :institution_id,
      :name,
      :type,
      :balance,
      :currency,
      :external_account_id,
      :is_manual,
      :is_active
    ])
    |> validate_required([:name, :type, :currency])
    |> validate_inclusion(:type, @valid_types)
    |> foreign_key_constraint(:institution_id)
  end
end
