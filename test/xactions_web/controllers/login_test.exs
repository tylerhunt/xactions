defmodule XactionsWeb.LoginTest do
  use XactionsWeb.ConnCase

  describe "mount" do
    test "renders login card", %{conn: conn} do
      conn = get(conn, ~p"/login")
      assert html_response(conn, 200) =~ "data-login-card"
    end

    test "renders login form", %{conn: conn} do
      conn = get(conn, ~p"/login")
      assert html_response(conn, 200) =~ "data-login-form"
    end
  end

  describe "design system" do
    test "does not use DaisyUI component classes", %{conn: conn} do
      conn = get(conn, ~p"/login")
      html = html_response(conn, 200)
      refute html =~ "card-body"
      refute html =~ "bg-base-100"
      refute html =~ "btn-primary"
      refute html =~ "shadow-xl"
      refute html =~ "label-text"
    end
  end
end
