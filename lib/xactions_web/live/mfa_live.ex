defmodule XactionsWeb.MfaLive do
  use XactionsWeb, :live_view

  alias Xactions.Sync.MFACoordinator

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Xactions.PubSub, "sync:status")
    end

    {:ok, assign(socket, :pending_mfa, [])}
  end

  @impl true
  def handle_info({:mfa_required, institution_id, mfa_type}, socket) do
    pending = [{institution_id, mfa_type, ""} | socket.assigns.pending_mfa]
    {:noreply, assign(socket, :pending_mfa, pending)}
  end

  @impl true
  def handle_info({:mfa_resolved, institution_id}, socket) do
    pending = Enum.reject(socket.assigns.pending_mfa, &(elem(&1, 0) == institution_id))
    {:noreply, assign(socket, :pending_mfa, pending)}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def handle_event("update_code", %{"id" => id, "code" => code}, socket) do
    id = String.to_integer(id)
    pending = Enum.map(socket.assigns.pending_mfa, fn
      {^id, type, _} -> {id, type, code}
      other -> other
    end)
    {:noreply, assign(socket, :pending_mfa, pending)}
  end

  @impl true
  def handle_event("submit_mfa", %{"id" => id, "code" => code}, socket) do
    MFACoordinator.resolve_mfa(String.to_integer(id), code)
    {:noreply, socket}
  end

  @impl true
  def handle_event("dismiss_mfa", %{"id" => id}, socket) do
    MFACoordinator.dismiss_mfa(String.to_integer(id))
    pending = Enum.reject(socket.assigns.pending_mfa, &(elem(&1, 0) == String.to_integer(id)))
    {:noreply, assign(socket, :pending_mfa, pending)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= for {institution_id, mfa_type, code} <- @pending_mfa do %>
      <div class="modal modal-open" id={"mfa-modal-#{institution_id}"}>
        <div class="modal-box">
          <h3 class="font-bold text-lg">Two-Factor Authentication</h3>
          <p class="py-2 text-sm text-base-content/70">
            <%= mfa_prompt(mfa_type) %>
          </p>
          <div class="form-control mt-4">
            <input
              type="text"
              class="input input-bordered"
              placeholder="Enter code"
              value={code}
              phx-keyup="update_code"
              phx-value-id={institution_id}
              phx-value-code=""
              autofocus
            />
          </div>
          <div class="modal-action">
            <button
              class="btn btn-primary"
              phx-click="submit_mfa"
              phx-value-id={institution_id}
              phx-value-code={code}
            >
              Submit
            </button>
            <button
              class="btn btn-ghost"
              phx-click="dismiss_mfa"
              phx-value-id={institution_id}
            >
              Cancel
            </button>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp mfa_prompt(:sms), do: "Enter the SMS code sent to your phone."
  defp mfa_prompt(:push), do: "Approve the push notification, then enter the confirmation code."
  defp mfa_prompt(:totp), do: "Enter the code from your authenticator app."
  defp mfa_prompt(_), do: "Enter your authentication code."
end
