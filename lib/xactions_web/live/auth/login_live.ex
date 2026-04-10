defmodule XactionsWeb.LoginLive do
  use XactionsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{"password" => ""}), error: nil)}
  end

  @impl true
  def handle_event("submit", %{"password" => password}, socket) do
    hashed = Application.get_env(:xactions, :hashed_password)

    if hashed && Bcrypt.verify_pass(password, hashed) do
      {:noreply,
       socket
       |> put_session_and_redirect()}
    else
      {:noreply, assign(socket, error: "Invalid password.")}
    end
  end

  defp put_session_and_redirect(socket) do
    push_navigate(socket, to: "/")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-[#f8f7f5]">
      <div class="bg-white border border-black/[.08] rounded-xl p-8 w-full max-w-sm" data-login-card>
        <h2 class="text-2xl tracking-tight text-[#030213] mb-1">xactions</h2>
        <p class="text-sm text-[#717182] mb-6">Sign in to continue</p>
        <.form for={@form} phx-submit="submit" data-login-form>
          <div class="mb-4">
            <label class="block text-xs text-[#717182] mb-1">Password</label>
            <input
              type="password"
              name="password"
              class="w-full border border-black/[.08] rounded-lg px-3 py-2 text-sm"
              autofocus
            />
          </div>
          <%= if @error do %>
            <p class="text-[#d4183d] text-sm mb-4">{@error}</p>
          <% end %>
          <button
            type="submit"
            class="w-full px-4 py-2 bg-[#030213] text-white rounded-lg text-sm hover:bg-[#030213]/90 transition-colors"
          >
            Sign In
          </button>
        </.form>
      </div>
    </div>
    """
  end
end
