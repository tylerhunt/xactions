defmodule Xactions.Budgeting.EnvelopeCategory do
  use Ecto.Schema
  import Ecto.Changeset

  schema "envelope_categories" do
    belongs_to :budget_envelope, Xactions.Budgeting.BudgetEnvelope
    belongs_to :category, Xactions.Transactions.Category

    timestamps(type: :utc_datetime)
  end

  def changeset(envelope_category, attrs) do
    envelope_category
    |> cast(attrs, [:budget_envelope_id, :category_id])
    |> validate_required([:budget_envelope_id, :category_id])
    |> foreign_key_constraint(:budget_envelope_id)
    |> foreign_key_constraint(:category_id)
    |> unique_constraint(:category_id,
      message: "category is already assigned to another envelope"
    )
  end
end
