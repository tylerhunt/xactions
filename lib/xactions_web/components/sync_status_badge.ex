defmodule XactionsWeb.Components.SyncStatusBadge do
  use Phoenix.Component

  attr :status, :string, required: true
  attr :last_synced_at, :any, default: nil

  def sync_status_badge(assigns) do
    ~H"""
    <span class={badge_class(@status)} data-sync-status={@status}>
      {label(@status)}
    </span>
    """
  end

  defp badge_class("active"),
    do: "text-xs font-medium px-2 py-0.5 rounded-full bg-[#10b981]/10 text-[#10b981]"

  defp badge_class("syncing"),
    do:
      "text-xs font-medium px-2 py-0.5 rounded-full bg-[#3b82f6]/10 text-[#3b82f6] animate-pulse"

  defp badge_class("mfa_required"),
    do: "text-xs font-medium px-2 py-0.5 rounded-full bg-[#f59e0b]/10 text-[#f59e0b]"

  defp badge_class("credential_error"),
    do: "text-xs font-medium px-2 py-0.5 rounded-full bg-[#d4183d]/10 text-[#d4183d]"

  defp badge_class("error"),
    do: "text-xs font-medium px-2 py-0.5 rounded-full bg-[#d4183d]/10 text-[#d4183d]"

  defp badge_class("inactive"),
    do: "text-xs font-medium px-2 py-0.5 rounded-full bg-[#717182]/10 text-[#717182]"

  defp badge_class(_),
    do: "text-xs font-medium px-2 py-0.5 rounded-full bg-[#717182]/10 text-[#717182]"

  defp label("active"), do: "Active"
  defp label("syncing"), do: "Syncing…"
  defp label("mfa_required"), do: "MFA Required"
  defp label("credential_error"), do: "Reconnect"
  defp label("error"), do: "Error"
  defp label("inactive"), do: "Inactive"
  defp label(other), do: other
end
