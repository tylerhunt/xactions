defmodule XactionsWeb.PageController do
  use XactionsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
