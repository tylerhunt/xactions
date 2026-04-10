defmodule XactionsWeb.DashboardLiveTest do
  use XactionsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Xactions.Fixtures

  setup %{conn: conn} do
    {:ok, conn: authenticated_conn(conn)}
  end

  describe "mount" do
    test "renders dashboard", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "xactions"
    end

    test "shows accounts grouped by institution", %{conn: conn} do
      inst = institution!(%{name: "My Bank"})
      _account = account!(%{institution_id: inst.id, name: "Checking"})
      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, "[data-institution-name='My Bank']")
      assert has_element?(view, "[data-account-name='Checking']")
    end

    test "shows reconnect alert for credential_error institutions", %{conn: conn} do
      inst = institution!(%{name: "Bad Bank", status: "credential_error"})
      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, "[data-reconnect-alert='#{inst.id}']")
    end
  end

  describe "sync_now event" do
    test "triggers sync for institution", %{conn: conn} do
      inst = institution!(%{scraper_module: "Xactions.FakeScraper"})
      {:ok, view, _html} = live(conn, ~p"/")

      Phoenix.PubSub.subscribe(Xactions.PubSub, "sync:status")
      inst_id = inst.id

      view
      |> element("[phx-click='sync_now'][phx-value-id='#{inst_id}']")
      |> render_click()

      assert_receive {:sync_started, ^inst_id}, 1000
    end
  end

  describe "design system" do
    test "renders net worth summary card", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, "[data-summary='net-worth']")
    end

    test "renders sync all button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, "[data-sync-all-btn]")
    end

    test "does not use DaisyUI component classes", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      refute html =~ "stat-title"
      refute html =~ "stat-value"
      refute html =~ "btn-ghost"
      refute html =~ "card-body"
      refute html =~ "alert-error"
    end
  end

  describe "PubSub updates" do
    test "updates sync status badge on sync_complete", %{conn: conn} do
      inst = institution!(%{name: "Live Bank"})
      {:ok, view, _html} = live(conn, ~p"/")

      Phoenix.PubSub.broadcast(Xactions.PubSub, "sync:status", {:sync_complete, inst.id})
      :timer.sleep(50)

      assert has_element?(view, "[data-institution-id='#{inst.id}']")
    end
  end
end
