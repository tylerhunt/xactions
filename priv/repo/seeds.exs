# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Safe to run multiple times — uses on_conflict: :nothing.

alias Xactions.Repo
alias Xactions.Transactions.Category

system_categories = [
  %{name: "Income", icon: "banknotes"},
  %{name: "Housing", icon: "home"},
  %{name: "Food & Drink", icon: "cake"},
  %{name: "Transport", icon: "truck"},
  %{name: "Shopping", icon: "shopping-bag"},
  %{name: "Health", icon: "heart"},
  %{name: "Entertainment", icon: "musical-note"},
  %{name: "Utilities", icon: "bolt"},
  %{name: "Travel", icon: "globe-alt"},
  %{name: "Finance", icon: "chart-bar"},
  %{name: "Transfer", icon: "arrows-right-left"},
  %{name: "Uncategorized", icon: "question-mark-circle"}
]

now = DateTime.utc_now() |> DateTime.truncate(:second)

for attrs <- system_categories do
  Repo.insert!(
    %Category{
      name: attrs.name,
      icon: attrs.icon,
      is_system: true,
      inserted_at: now,
      updated_at: now
    },
    on_conflict: :nothing
  )
end

IO.puts("Seeded #{length(system_categories)} system categories.")
