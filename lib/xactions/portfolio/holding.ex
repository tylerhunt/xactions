defmodule Xactions.Portfolio.Holding do
  use Ecto.Schema
  import Ecto.Changeset

  schema "holdings" do
    field :symbol, :string
    field :name, :string
    field :quantity, :decimal
    field :cost_basis, :decimal
    field :current_price, :decimal
    field :price_as_of, :utc_datetime
    field :asset_class, :string, default: "equity"
    field :external_security_id, :string

    # Virtual computed fields (populated by context queries)
    field :current_value, :decimal, virtual: true
    field :unrealized_gain_loss, :decimal, virtual: true
    field :unrealized_gain_loss_pct, :decimal, virtual: true

    belongs_to :account, Xactions.Accounts.Account

    timestamps(type: :utc_datetime)
  end

  @valid_asset_classes ~w(equity fixed_income etf mutual_fund cash crypto other)

  def changeset(holding, attrs) do
    holding
    |> cast(attrs, [
      :account_id,
      :symbol,
      :name,
      :quantity,
      :cost_basis,
      :current_price,
      :price_as_of,
      :asset_class,
      :external_security_id
    ])
    |> validate_required([:account_id, :symbol, :quantity, :asset_class])
    |> validate_inclusion(:asset_class, @valid_asset_classes)
    |> foreign_key_constraint(:account_id)
    |> unique_constraint([:account_id, :symbol])
  end
end
