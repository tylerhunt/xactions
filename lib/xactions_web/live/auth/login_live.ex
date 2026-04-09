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
    <div class="min-h-screen flex items-center justify-center bg-base-200">
      <div class="card w-96 bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title text-2xl">xactions</h2>
          <p class="text-base-content/70">Sign in to continue</p>
          <.form for={@form} phx-submit="submit" class="mt-4 space-y-4">
            <div class="form-control">
              <label class="label"><span class="label-text">Password</span></label>
              <input
                type="password"
                name="password"
                class="input input-bordered w-full"
                autofocus
              />
            </div>
            <%= if @error do %>
              <p class="text-error text-sm"><%= @error %></p>
            <% end %>
            <button type="submit" class="btn btn-primary w-full">Sign In</button>
          </.form>
        </div>
      </div>
    </div>
    """
  end
end
