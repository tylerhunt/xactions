defmodule Xactions.Transactions.Category do
  use Ecto.Schema
  import Ecto.Changeset

  schema "categories" do
    field :name, :string
    field :icon, :string
    field :is_system, :boolean, default: false

    belongs_to :parent, __MODULE__, foreign_key: :parent_id
    has_many :subcategories, __MODULE__, foreign_key: :parent_id
    has_many :transactions, Xactions.Transactions.Transaction
    has_one :envelope_category, Xactions.Budgeting.EnvelopeCategory

    timestamps(type: :utc_datetime)
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :icon, :parent_id, :is_system])
    |> validate_required([:name])
    |> foreign_key_constraint(:parent_id)
    |> no_assoc_constraint(:transactions,
      message: "cannot delete a category that has transactions"
    )
  end
end
