defmodule Xactions.Budgeting.BudgetMonth do
  use Ecto.Schema
  import Ecto.Changeset

  schema "budget_months" do
    field :month, :integer
    field :year, :integer
    field :allocated_amount, :decimal, default: Decimal.new("0.00")

    belongs_to :budget_envelope, Xactions.Budgeting.BudgetEnvelope

    timestamps(type: :utc_datetime)
  end

  def changeset(budget_month, attrs) do
    budget_month
    |> cast(attrs, [:budget_envelope_id, :month, :year, :allocated_amount])
    |> validate_required([:budget_envelope_id, :month, :year, :allocated_amount])
    |> validate_number(:month, greater_than_or_equal_to: 1, less_than_or_equal_to: 12)
    |> validate_number(:year, greater_than_or_equal_to: 2000)
    |> foreign_key_constraint(:budget_envelope_id)
    |> unique_constraint([:budget_envelope_id, :month, :year])
  end
end
