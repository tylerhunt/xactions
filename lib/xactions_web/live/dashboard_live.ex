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
        if inst.id == institution_id,
          do: {%{inst | status: status}, accounts},
          else: {inst, accounts}
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
    <div class="min-h-screen bg-[#f8f7f5]">
      <div class="max-w-5xl mx-auto px-6 py-8">
        <div class="flex items-center justify-between mb-6">
          <h1 class="text-2xl tracking-tight">Dashboard</h1>
          <button
            data-sync-all-btn
            class="px-4 py-2 hover:bg-[#ececea] rounded-lg text-sm transition-colors text-[#717182] hover:text-[#030213]"
            phx-click="sync_all"
          >
            Sync All
          </button>
        </div>

        <%!-- Net Worth Summary Card --%>
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
          <div data-summary="net-worth" class="bg-white border border-black/[.08] rounded-xl p-5">
            <div class="text-sm text-[#717182] mb-1">Net Worth</div>
            <div class="text-3xl tracking-tight">
              ${Decimal.to_string(Decimal.round(@net_worth, 2))}
            </div>
          </div>
        </div>

        <%!-- Institution Cards --%>
        <div class="grid gap-4">
          <%= for {institution, accounts} <- @institutions_with_accounts do %>
            <div
              class="bg-white border border-black/[.08] rounded-xl overflow-hidden"
              data-institution-id={institution.id}
              data-institution-name={institution.name}
            >
              <div class="px-5 py-4">
                <div class="flex items-center justify-between mb-3">
                  <div class="flex items-center gap-2">
                    <span class="font-medium text-[#030213]">{institution.name}</span>
                    <.sync_status_badge status={institution.status} />
                  </div>
                  <button
                    class="p-1.5 rounded hover:bg-[#ececea] transition-colors text-[#717182] hover:text-[#030213] text-xs"
                    phx-click="sync_now"
                    phx-value-id={institution.id}
                  >
                    Sync
                  </button>
                </div>

                <%= if institution.status == "credential_error" do %>
                  <div
                    class="border-l-4 border-[#d4183d] bg-[#d4183d]/5 rounded-lg px-4 py-3 text-sm text-[#030213] mb-3"
                    data-reconnect-alert={institution.id}
                  >
                    Credentials invalid.
                    <.link navigate={~p"/accounts"} class="underline ml-1">Reconnect</.link>
                  </div>
                <% end %>

                <div class="divide-y divide-black/[.04]">
                  <%= for account <- accounts do %>
                    <div
                      class="flex justify-between py-2"
                      data-account-name={account.name}
                      data-account-id={account.id}
                    >
                      <span class="text-sm text-[#030213]">{account.name}</span>
                      <span class="font-mono text-sm text-[#030213]">
                        ${Decimal.to_string(Decimal.round(account.balance || Decimal.new("0"), 2))}
                      </span>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
