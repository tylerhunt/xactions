defmodule XactionsWeb.Components.SyncStatusBadge do
  use Phoenix.Component

  attr :status, :string, required: true
  attr :last_synced_at, :any, default: nil

  def sync_status_badge(assigns) do
    ~H"""
    <span class={badge_class(@status)} data-sync-status={@status}>
      <%= label(@status) %>
    </span>
    """
  end

  defp badge_class("active"), do: "badge badge-success badge-sm"
  defp badge_class("syncing"), do: "badge badge-info badge-sm animate-pulse"
  defp badge_class("mfa_required"), do: "badge badge-warning badge-sm"
  defp badge_class("credential_error"), do: "badge badge-error badge-sm"
  defp badge_class("error"), do: "badge badge-error badge-sm"
  defp badge_class("inactive"), do: "badge badge-ghost badge-sm"
  defp badge_class(_), do: "badge badge-ghost badge-sm"

  defp label("active"), do: "Active"
  defp label("syncing"), do: "Syncing…"
  defp label("mfa_required"), do: "MFA Required"
  defp label("credential_error"), do: "Reconnect"
  defp label("error"), do: "Error"
  defp label("inactive"), do: "Inactive"
  defp label(other), do: other
end
