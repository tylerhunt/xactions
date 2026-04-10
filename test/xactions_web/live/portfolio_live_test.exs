defmodule XactionsWeb.PortfolioLiveTest do
  use XactionsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Xactions.Fixtures

  setup %{conn: conn} do
    {:ok, conn: authenticated_conn(conn)}
  end

  describe "mount" do
    test "renders portfolio page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/portfolio")
      assert html =~ "Portfolio"
    end

    test "shows empty state when no holdings", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/portfolio")
      assert html =~ "No holdings"
    end

    test "renders holdings list", %{conn: conn} do
      inst = institution!()
      account = account!(%{institution_id: inst.id, type: "brokerage"})
      holding!(%{account_id: account.id, symbol: "AAPL", name: "Apple Inc.",
                 quantity: Decimal.new("10"), current_price: Decimal.new("185.40")})

      {:ok, view, _html} = live(conn, ~p"/portfolio")
      assert has_element?(view, "[data-symbol='AAPL']")
    end

    test "shows stale price banner when data is older than 15 minutes", %{conn: conn} do
      inst = institution!()
      account = account!(%{institution_id: inst.id, type: "brokerage"})
      stale_time = DateTime.add(DateTime.utc_now(), -20 * 60, :second)
      holding!(%{account_id: account.id, symbol: "AAPL", name: "Apple",
                 quantity: Decimal.new("1"), current_price: Decimal.new("100"),
                 price_as_of: DateTime.truncate(stale_time, :second)})

      {:ok, view, _html} = live(conn, ~p"/portfolio")
      assert has_element?(view, "[data-price-stale]")
    end
  end

  describe "design system" do
    test "renders summary cards", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/portfolio")
      assert has_element?(view, "[data-summary='total-value']")
      assert has_element?(view, "[data-summary='cost-basis']")
      assert has_element?(view, "[data-summary='gain-loss']")
    end

    test "renders period toggle buttons", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/portfolio")
      assert has_element?(view, "[data-period-btn]")
    end

    test "does not use DaisyUI component classes", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/portfolio")
      refute html =~ "stat-title"
      refute html =~ "stat-value"
      refute html =~ "btn-primary"
      refute html =~ "btn-ghost"
    end
  end

  describe "set_period event" do
    test "updates selected period", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/portfolio")

      view
      |> element("[phx-click='set_period'][phx-value-period='m3']")
      |> render_click()

      assert has_element?(view, "[data-period='m3'][data-active='true']")
    end
  end
end
