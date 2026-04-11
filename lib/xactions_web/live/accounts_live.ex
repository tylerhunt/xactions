defmodule XactionsWeb.AccountsLive do
  use XactionsWeb, :live_view

  alias Xactions.Accounts
  alias Xactions.Accounts.Institution
  alias Xactions.Sync.SyncScheduler
  import XactionsWeb.Components.SyncStatusBadge

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Xactions.PubSub, "sync:status")
    end

    {:ok,
     socket
     |> assign(:institutions, list_institutions_with_accounts())
     |> assign(:show_form, false)
     |> assign(:editing_institution, nil)
     |> assign(:form, build_form())}
  end

  @impl true
  def handle_event("add_institution", _params, socket) do
    {:noreply, assign(socket, show_form: true, form: build_form())}
  end

  @impl true
  def handle_event("cancel_form", _params, socket) do
    {:noreply, assign(socket, show_form: false, editing_institution: nil)}
  end

  @impl true
  def handle_event("save_institution", %{"institution" => attrs}, socket) do
    case Accounts.create_institution(attrs) do
      {:ok, _institution} ->
        {:noreply,
         socket
         |> assign(:institutions, list_institutions_with_accounts())
         |> assign(:show_form, false)}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :institution))}
    end
  end

  @impl true
  def handle_event("remove_institution", %{"id" => id}, socket) do
    institution = Accounts.get_institution!(id)
    Accounts.disconnect_institution(institution)

    {:noreply, assign(socket, :institutions, list_institutions_with_accounts())}
  end

  @impl true
  def handle_event("sync_now", %{"id" => id}, socket) do
    SyncScheduler.sync_now(String.to_integer(id))
    {:noreply, socket}
  end

  @impl true
  def handle_info({:sync_started, institution_id}, socket) do
    {:noreply, update_institution_status(socket, institution_id, "syncing")}
  end

  @impl true
  def handle_info({:sync_complete, institution_id}, socket) do
    {:noreply,
     socket
     |> update_institution_status(institution_id, "active")
     |> assign(:institutions, list_institutions_with_accounts())}
  end

  @impl true
  def handle_info({:mfa_required, institution_id, _type}, socket) do
    {:noreply, update_institution_status(socket, institution_id, "mfa_required")}
  end

  @impl true
  def handle_info({:credential_error, institution_id}, socket) do
    {:noreply, update_institution_status(socket, institution_id, "credential_error")}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  defp update_institution_status(socket, institution_id, status) do
    institutions =
      Enum.map(socket.assigns.institutions, fn {inst, accounts} ->
        if inst.id == institution_id do
          {%{inst | status: status}, accounts}
        else
          {inst, accounts}
        end
      end)

    assign(socket, :institutions, institutions)
  end

  defp list_institutions_with_accounts do
    Accounts.list_institutions()
    |> Enum.map(fn inst ->
      {inst, Accounts.list_accounts_for_institution(inst.id)}
    end)
  end

  defp build_form do
    %Institution{}
    |> Institution.changeset(%{})
    |> to_form(as: :institution)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#f8f7f5]">
      <div class="max-w-4xl mx-auto px-6 py-8">
        <div class="flex items-center justify-between mb-6">
          <h1 class="text-2xl tracking-tight">Accounts</h1>
          <button
            class="px-4 py-2 bg-[#030213] text-white rounded-lg text-sm hover:bg-[#030213]/90 transition-colors"
            phx-click="add_institution"
          >
            Add Institution
          </button>
        </div>

        <%= if @show_form do %>
          <div class="bg-white border border-black/[.08] rounded-xl p-5 mb-6">
            <h2 class="text-base font-medium text-[#030213] mb-4">Add Institution</h2>
            <.form
              for={@form}
              phx-submit="save_institution"
              data-form="add-institution"
            >
              <.input field={@form[:name]} type="text" label="Name" placeholder="Chase, Fidelity…" />
              <.input
                field={@form[:sync_method]}
                type="select"
                label="Sync Method"
                options={[
                  {"Browser (Playwright)", "browser"},
                  {"OFX Direct Connect", "ofx_direct"},
                  {"Manual", "manual"}
                ]}
              />
              <div class="flex gap-2 mt-4">
                <button
                  type="submit"
                  class="px-4 py-2 bg-[#030213] text-white rounded-lg text-sm hover:bg-[#030213]/90 transition-colors"
                >
                  Save
                </button>
                <button
                  type="button"
                  class="px-4 py-2 hover:bg-[#ececea] rounded-lg text-sm hover:text-[#030213] transition-colors"
                  phx-click="cancel_form"
                >
                  Cancel
                </button>
              </div>
            </.form>
          </div>
        <% end %>

        <div class="grid gap-4">
          <%= for {institution, accounts} <- @institutions do %>
            <div
              class="bg-white border border-black/[.08] rounded-xl overflow-hidden"
              data-institution-id={institution.id}
              data-institution-name={institution.name}
            >
              <div class="px-5 py-4">
                <div class="flex items-center justify-between mb-3">
                  <div class="flex items-center gap-3">
                    <span class="font-medium text-[#030213]">{institution.name}</span>
                    <.sync_status_badge status={institution.status} />
                  </div>
                  <div class="flex gap-1">
                    <%= unless institution.is_manual_only do %>
                      <button
                        class="px-2 py-1 hover:bg-[#ececea] rounded text-xs hover:text-[#030213] transition-colors"
                        phx-click="sync_now"
                        phx-value-id={institution.id}
                      >
                        Sync
                      </button>
                    <% end %>
                    <button
                      class="px-2 py-1 hover:bg-[#ececea] rounded text-xs text-[#d4183d]/70 hover:text-[#d4183d] transition-colors"
                      phx-click="remove_institution"
                      phx-value-id={institution.id}
                      data-confirm="Remove this institution and all its data?"
                    >
                      Remove
                    </button>
                  </div>
                </div>

                <%= if institution.status == "credential_error" do %>
                  <div
                    class="border-l-4 border-[#d4183d] bg-[#d4183d]/5 rounded-lg px-4 py-3 text-sm text-[#030213] mb-3"
                    data-reconnect-alert={institution.id}
                  >
                    Credentials invalid — please update and reconnect.
                  </div>
                <% end %>

                <div class="divide-y divide-black/[.04]">
                  <%= for account <- accounts do %>
                    <div
                      class="flex items-center justify-between py-2"
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
