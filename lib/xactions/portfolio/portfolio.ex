defmodule Xactions.Portfolio do
  @moduledoc """
  Context for investment portfolio holdings, allocation, and price data.
  """

  import Ecto.Query

  alias Xactions.Repo
  alias Xactions.Portfolio.Holding

  @doc """
  Returns all holdings with computed virtual fields:
  - `current_value` = quantity × current_price
  - `unrealized_gain_loss` = current_value - cost_basis (nil if no cost_basis)
  - `unrealized_gain_loss_pct` = gain_loss / cost_basis × 100 (nil if no cost_basis)
  """
  def list_holdings do
    Holding
    |> order_by([h], [asc: h.asset_class, asc: h.symbol])
    |> Repo.all()
    |> Enum.map(&compute_virtual_fields/1)
  end

  @doc """
  Returns allocation broken down by asset class.
  Each entry: `%{class: string, value: Decimal, pct: float}`
  """
  def get_allocation do
    holdings = list_holdings()
    total = Enum.reduce(holdings, Decimal.new("0"), fn h, acc ->
      Decimal.add(acc, h.current_value || Decimal.new("0"))
    end)

    if Decimal.equal?(total, Decimal.new("0")) do
      []
    else
      holdings
      |> Enum.group_by(& &1.asset_class)
      |> Enum.map(fn {class, group} -> allocation_entry(class, group, total) end)
      |> Enum.sort_by(& &1.pct, :desc)
    end
  end

  defp allocation_entry(class, group, total) do
    value = Enum.reduce(group, Decimal.new("0"), fn h, acc ->
      Decimal.add(acc, h.current_value || Decimal.new("0"))
    end)

    pct =
      value
      |> Decimal.div(total)
      |> Decimal.mult(Decimal.new("100"))
      |> Decimal.to_float()

    %{class: class, value: value, pct: pct}
  end

  @doc """
  Replaces all holdings for an account (delete-then-insert) from OFX sync data.
  Returns `{:ok, count}` where count is the number of inserted holdings.
  """
  def replace_holdings_for_account(account_id, holding_attrs) do
    Repo.transaction(fn ->
      Repo.delete_all(from h in Holding, where: h.account_id == ^account_id)

      for attrs <- holding_attrs do
        Repo.insert!(%Holding{
          account_id: account_id,
          symbol: Map.get(attrs, :symbol),
          name: Map.get(attrs, :name),
          quantity: Map.get(attrs, :quantity),
          cost_basis: Map.get(attrs, :cost_basis),
          current_price: Map.get(attrs, :current_price),
          price_as_of: Map.get(attrs, :price_as_of),
          asset_class: Map.get(attrs, :asset_class, "equity"),
          external_security_id: Map.get(attrs, :external_security_id)
        })
      end

      length(holding_attrs)
    end)
  end

  @doc """
  Returns the oldest `price_as_of` timestamp across all holdings (nil if none).
  """
  def oldest_price_timestamp do
    Repo.one(from h in Holding, select: min(h.price_as_of))
  end

  defp compute_virtual_fields(%Holding{} = h) do
    current_value =
      if h.quantity && h.current_price do
        Decimal.mult(h.quantity, h.current_price)
      end

    gain_loss =
      if current_value && h.cost_basis do
        Decimal.sub(current_value, h.cost_basis)
      end

    gain_loss_pct =
      if gain_loss && h.cost_basis && !Decimal.equal?(h.cost_basis, Decimal.new("0")) do
        Decimal.div(gain_loss, h.cost_basis) |> Decimal.mult(Decimal.new("100"))
      end

    %{h | current_value: current_value, unrealized_gain_loss: gain_loss,
          unrealized_gain_loss_pct: gain_loss_pct}
  end
end
