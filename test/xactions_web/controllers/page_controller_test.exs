defmodule XactionsWeb.PageControllerTest do
  use XactionsWeb.ConnCase

  test "GET / redirects to login when unauthenticated", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/login"
  end

  test "GET / renders when authenticated", %{conn: conn} do
    conn = authenticated_conn(conn) |> get(~p"/")
    assert html_response(conn, 200)
  end
end
