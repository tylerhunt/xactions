defmodule XactionsWeb.DashboardLive do
  use XactionsWeb, :live_view

  alias Xactions.{Accounts, Reporting}
  alias Xactions.Sync.SyncScheduler
  import XactionsWeb.Components.SyncStatusBadge

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Xactions.PubSub, "sync:status")
    end

    {:ok,
     socket
     |> assign(:institutions_with_accounts, load_institutions())
     |> load_net_worth()}
  end

  @impl true
  def handle_event("sync_now", %{"id" => id}, socket) do
    SyncScheduler.sync_now(String.to_integer(id))
    {:noreply, socket}
  end

  @impl true
  def handle_event("sync_all", _params, socket) do
    SyncScheduler.sync_all()
    {:noreply, socket}
  end

  @impl true
  def handle_info({:sync_started, institution_id}, socket) do
    {:noreply, update_status(socket, institution_id, "syncing")}
  end

  @impl true
  def handle_info({:sync_complete, institution_id}, socket) do
    {:noreply,
     socket
     |> update_status(institution_id, "active")
     |> assign(:institutions_with_accounts, load_institutions())}
  end

  @impl true
  def handle_info({:mfa_required, institution_id, _type}, socket) do
    {:noreply, update_status(socket, institution_id, "mfa_required")}
  end

  @impl true
  def handle_info({:credential_error, institution_id}, socket) do
    {:noreply, update_status(socket, institution_id, "credential_error")}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  defp update_status(socket, institution_id, status) do
    updated =
      Enum.map(socket.assigns.institutions_with_accounts, fn {inst, accounts} ->
        if inst.id == institution_id, do: {%{inst | status: status}, accounts}, else: {inst, accounts}
      end)

    assign(socket, :institutions_with_accounts, updated)
  end

  defp load_institutions do
    Accounts.list_institutions()
    |> Enum.map(&{&1, Accounts.list_accounts_for_institution(&1.id)})
  end

  defp load_net_worth(socket) do
    nw = Reporting.net_worth()
    assign(socket, :net_worth, nw)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-6 max-w-5xl">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold">xactions</h1>
        <button class="btn btn-ghost btn-sm" phx-click="sync_all">Sync All</button>
      </div>

      <%!-- Net Worth Panel --%>
      <div class="stats shadow mb-6" data-net-worth-panel>
        <div class="stat">
          <div class="stat-title">Net Worth</div>
          <div class="stat-value text-xl">
            $<%= Decimal.to_string(Decimal.round(@net_worth, 2)) %>
          </div>
        </div>
      </div>

      <div class="grid gap-4">
        <%= for {institution, accounts} <- @institutions_with_accounts do %>
          <div
            class="card bg-base-100 border"
            data-institution-id={institution.id}
            data-institution-name={institution.name}
          >
            <div class="card-body p-4">
              <div class="flex items-center justify-between mb-2">
                <div class="flex items-center gap-2">
                  <span class="font-semibold"><%= institution.name %></span>
                  <.sync_status_badge status={institution.status} />
                </div>
                <button
                  class="btn btn-ghost btn-xs"
                  phx-click="sync_now"
                  phx-value-id={institution.id}
                >
                  Sync
                </button>
              </div>

              <%= if institution.status == "credential_error" do %>
                <div class="alert alert-error alert-sm mb-2" data-reconnect-alert={institution.id}>
                  <span>Credentials invalid.</span>
                  <.link navigate={~p"/accounts"} class="link">Reconnect</.link>
                </div>
              <% end %>

              <div class="divide-y divide-base-200">
                <%= for account <- accounts do %>
                  <div
                    class="flex justify-between py-1.5"
                    data-account-name={account.name}
                    data-account-id={account.id}
                  >
                    <span class="text-sm"><%= account.name %></span>
                    <span class="font-mono text-sm">
                      $<%= Decimal.to_string(Decimal.round(account.balance || Decimal.new("0"), 2)) %>
                    </span>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
