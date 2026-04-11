defmodule XactionsWeb.AuthPlug do
  @moduledoc "Plug that enforces session authentication, redirecting to /login if unauthenticated."

  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    if get_session(conn, :authenticated) do
      conn
    else
      conn
      |> redirect(to: "/login")
      |> halt()
    end
  end
end
