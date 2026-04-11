defmodule Xactions.Fixtures do
  @moduledoc "Test factory helpers for creating database records."

  alias Xactions.Repo
  alias Xactions.Accounts.{Institution, Account}
  alias Xactions.Transactions.{Category, Transaction}
  alias Xactions.Portfolio.Holding
  alias Xactions.Budgeting.{BudgetEnvelope, BudgetMonth, EnvelopeCategory}

  def institution_attrs(attrs \\ %{}) do
    Map.merge(
      %{
        name: "Test Bank #{System.unique_integer()}",
        sync_method: "browser",
        status: "active",
        sync_interval_hours: 12,
        is_manual_only: false
      },
      attrs
    )
  end

  def institution!(attrs \\ %{}) do
    %Institution{}
    |> Institution.changeset(institution_attrs(attrs))
    |> Repo.insert!()
  end

  def account_attrs(attrs \\ %{}) do
    Map.merge(
      %{
        name: "Checking #{System.unique_integer()}",
        type: "checking",
        balance: Decimal.new("0.00"),
        currency: "USD",
        is_manual: false,
        is_active: true
      },
      attrs
    )
  end

  def account!(attrs \\ %{}) do
    %Account{}
    |> Account.changeset(account_attrs(attrs))
    |> Repo.insert!()
  end

  def category!(attrs \\ %{}) do
    defaults = %{
      name: "Category #{System.unique_integer()}",
      is_system: false
    }

    %Category{}
    |> Category.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  def transaction!(attrs \\ %{}) do
    defaults = %{
      date: Date.utc_today(),
      amount: Decimal.new("-10.00"),
      is_pending: false,
      is_split: false,
      is_manual: false
    }

    %Transaction{}
    |> Transaction.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  def holding!(attrs \\ %{}) do
    defaults = %{
      symbol: "AAPL",
      name: "Apple Inc.",
      quantity: Decimal.new("10.0"),
      asset_class: "equity"
    }

    %Holding{}
    |> Holding.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  def budget_envelope!(attrs \\ %{}) do
    defaults = %{name: "Envelope #{System.unique_integer()}", type: "fixed"}

    %BudgetEnvelope{}
    |> BudgetEnvelope.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  def budget_month!(attrs \\ %{}) do
    %BudgetMonth{}
    |> BudgetMonth.changeset(attrs)
    |> Repo.insert!()
  end

  def envelope_category!(attrs \\ %{}) do
    %EnvelopeCategory{}
    |> EnvelopeCategory.changeset(attrs)
    |> Repo.insert!()
  end
end
