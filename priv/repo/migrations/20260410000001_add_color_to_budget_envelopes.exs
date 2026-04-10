defmodule Xactions.Repo.Migrations.AddColorToBudgetEnvelopes do
  use Ecto.Migration

  def change do
    alter table(:budget_envelopes) do
      add :color, :string
    end
  end
end
