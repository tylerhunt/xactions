defmodule Xactions.Budgeting.BudgetEnvelope do
  use Ecto.Schema
  import Ecto.Changeset

  @palette ~w(#10b981 #3b82f6 #f59e0b #ec4899 #8b5cf6 #06b6d4 #14b8a6 #f97316)

  schema "budget_envelopes" do
    field :name, :string
    field :type, :string
    field :color, :string
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
    |> cast(attrs, [:name, :type, :color, :rollover_cap, :archived_at])
    |> validate_required([:name, :type])
    |> validate_inclusion(:type, @valid_types)
    |> validate_format(:color, ~r/^#[0-9a-fA-F]{6}$/, message: "must be a valid hex color")
    |> put_default_color()
    |> validate_rollover_cap()
  end

  defp put_default_color(%Ecto.Changeset{data: %{id: nil}} = changeset) do
    if get_field(changeset, :color) do
      changeset
    else
      count = Xactions.Repo.aggregate(Xactions.Budgeting.BudgetEnvelope, :count)
      color = Enum.at(@palette, rem(count, length(@palette)))
      put_change(changeset, :color, color)
    end
  end

  defp put_default_color(changeset), do: changeset

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
