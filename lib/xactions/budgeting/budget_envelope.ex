defmodule Xactions.Budgeting.BudgetEnvelope do
  use Ecto.Schema
  import Ecto.Changeset

  schema "budget_envelopes" do
    field :name, :string
    field :type, :string
    field :rollover_cap, :decimal
    field :archived_at, :utc_datetime

    has_many :budget_months, Xactions.Budgeting.BudgetMonth
    has_many :envelope_categories, Xactions.Budgeting.EnvelopeCategory
    has_many :categories, through: [:envelope_categories, :category]

    timestamps(type: :utc_datetime)
  end

  @valid_types ~w(fixed variable rollover)

  def changeset(envelope, attrs) do
    envelope
    |> cast(attrs, [:name, :type, :rollover_cap, :archived_at])
    |> validate_required([:name, :type])
    |> validate_inclusion(:type, @valid_types)
    |> validate_rollover_cap()
  end

  defp validate_rollover_cap(changeset) do
    type = get_field(changeset, :type)
    cap = get_field(changeset, :rollover_cap)

    if type != "rollover" && cap != nil do
      add_error(changeset, :rollover_cap, "only rollover envelopes can have a cap")
    else
      changeset
    end
  end
end
