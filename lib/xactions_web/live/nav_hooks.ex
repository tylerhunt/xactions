defmodule XactionsWeb.NavHooks do
  @moduledoc "LiveView mount hooks for injecting navigation assigns."

  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:default, _params, _session, socket) do
    {:cont,
     attach_hook(socket, :set_current_path, :handle_params, fn _params, url, socket ->
       {:cont, assign(socket, :current_path, URI.parse(url).path)}
     end)}
  end
end
