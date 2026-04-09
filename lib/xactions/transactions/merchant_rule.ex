defmodule Xactions.Transactions.MerchantRule do
  use Ecto.Schema
  import Ecto.Changeset

  schema "merchant_category_rules" do
    field :merchant_pattern, :string
    belongs_to :category, Xactions.Transactions.Category

    timestamps(type: :utc_datetime)
  end

  def changeset(rule, attrs) do
    rule
    |> cast(attrs, [:merchant_pattern, :category_id])
    |> validate_required([:merchant_pattern, :category_id])
    |> unique_constraint(:merchant_pattern)
    |> foreign_key_constraint(:category_id)
  end

  def normalize_merchant(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/\s+\d+$/, "")
    |> String.replace(~r/[^\w\s]/, "")
    |> String.trim()
  end

  def normalize_merchant(_), do: nil
end
