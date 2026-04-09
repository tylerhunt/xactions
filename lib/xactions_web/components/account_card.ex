defmodule XactionsWeb.Components.AccountCard do
  use Phoenix.Component

  alias XactionsWeb.Components.SyncStatusBadge
  import SyncStatusBadge

  attr :account, :map, required: true

  def account_card(assigns) do
    ~H"""
    <div
      class="flex items-center justify-between py-2 px-3 rounded hover:bg-base-200"
      data-account-name={@account.name}
      data-account-id={@account.id}
    >
      <div>
        <span class="font-medium text-sm"><%= @account.name %></span>
        <span class="text-xs text-base-content/50 ml-2"><%= account_type_label(@account.type) %></span>
      </div>
      <span class={balance_class(@account)} data-account-balance={@account.id}>
        <%= format_balance(@account.balance) %>
      </span>
    </div>
    """
  end

  defp account_type_label("checking"), do: "Checking"
  defp account_type_label("savings"), do: "Savings"
  defp account_type_label("credit_card"), do: "Credit Card"
  defp account_type_label("loan"), do: "Loan"
  defp account_type_label("mortgage"), do: "Mortgage"
  defp account_type_label("brokerage"), do: "Brokerage"
  defp account_type_label(t), do: t

  defp balance_class(%{type: type}) when type in ~w(credit_card loan mortgage),
    do: "font-mono text-sm text-error"
  defp balance_class(_), do: "font-mono text-sm text-success"

  defp format_balance(nil), do: "$0.00"
  defp format_balance(balance) do
    "$#{Decimal.to_string(Decimal.round(balance, 2))}"
  end
end
