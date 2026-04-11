defmodule XactionsWeb.ReportsLiveTest do
  use XactionsWeb.ConnCase

  import Phoenix.LiveViewTest

  @today Date.utc_today()

  setup %{conn: conn} do
    {:ok, conn: authenticated_conn(conn)}
  end

  describe "mount" do
    test "renders reports page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/reports")
      assert html =~ "Reports"
    end

    test "shows current month by default", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/reports")
      assert html =~ Integer.to_string(@today.year)
    end
  end

  describe "select_month event" do
    test "updates selected month", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/reports")
      prev = Date.shift(@today, month: -1)
      month_str = Calendar.strftime(prev, "%Y-%m")

      view
      |> form("[data-form='month-select']", %{month: month_str})
      |> render_submit()

      assert has_element?(view, "[data-selected-month='#{month_str}']")
    end
  end

  describe "net worth panel" do
    test "displays net worth", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/reports")
      assert html =~ "Net Worth"
    end
  end

  describe "design system" do
    test "renders net worth summary card", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/reports")
      assert has_element?(view, "[data-summary='net-worth']")
    end

    test "does not use DaisyUI component classes", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/reports")
      refute html =~ "stat-title"
      refute html =~ "stat-value"
      refute html =~ "btn-ghost"
    end
  end
end
