defmodule XactionsWeb.NavigationTest do
  use XactionsWeb.ConnCase

  import Phoenix.LiveViewTest

  # T002: NavHooks assigns current_path via handle_params hook
  describe "NavHooks.on_mount/4" do
    setup %{conn: conn} do
      {:ok, conn: authenticated_conn(conn)}
    end

    test "assigns current_path to socket on each navigation", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts")
      # current_path="/accounts" causes Accounts link to be active
      assert has_element?(view, ".btn-active[href='/accounts']")
      # Navigate to "/" and confirm current_path updates
      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, ".btn-active[href='/']")
    end
  end

  # T005 (US1): Navbar renders with all six section links
  describe "US1 - persistent navbar" do
    setup %{conn: conn} do
      {:ok, conn: authenticated_conn(conn)}
    end

    test "renders all six section links on dashboard", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, "a[href='/']")
      assert has_element?(view, "a[href='/accounts']")
      assert has_element?(view, "a[href='/transactions']")
      assert has_element?(view, "a[href='/portfolio']")
      assert has_element?(view, "a[href='/budget']")
      assert has_element?(view, "a[href='/reports']")
    end
  end

  # T007 (US2): Dashboard nav link is active when visiting /
  # T008 (US2): Accounts nav link is active when visiting /accounts; Dashboard is not
  describe "US2 - active link highlighting" do
    setup %{conn: conn} do
      {:ok, conn: authenticated_conn(conn)}
    end

    test "Dashboard nav link has btn-active class when visiting /", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, ".btn-active[href='/']")
    end

    test "Accounts nav link has btn-active when visiting /accounts; Dashboard does not",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts")
      assert has_element?(view, ".btn-active[href='/accounts']")
      refute has_element?(view, ".btn-active[href='/']")
    end
  end

  # T010 (US3): Navbar contains Sign Out link targeting /logout
  # T011 (US3): Unauthenticated GET / redirects to /login
  describe "US3 - authentication state in nav" do
    setup %{conn: conn} do
      {:ok, conn: authenticated_conn(conn)}
    end

    test "navbar contains Sign Out link targeting /logout when authenticated", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, "a[href='/logout']")
    end

    test "unauthenticated GET / redirects to /login" do
      conn = build_conn()
      conn = get(conn, ~p"/")
      assert redirected_to(conn) == ~p"/login"
    end
  end
end
