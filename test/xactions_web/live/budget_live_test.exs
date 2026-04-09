defmodule XactionsWeb.BudgetLiveTest do
  use XactionsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Xactions.Fixtures

  @today Date.utc_today()

  setup %{conn: conn} do
    inst = institution!(%{is_manual_only: true})
    account = account!(%{institution_id: inst.id, is_manual: true})
    income_cat = category!(%{name: "Income"})
    food_cat = category!(%{name: "Food"})
    {:ok, conn: authenticated_conn(conn), account: account,
          income_cat: income_cat, food_cat: food_cat}
  end

  describe "mount" do
    test "renders budget page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/budget")
      assert html =~ "Budget"
    end

    test "shows TBB indicator", %{conn: conn, account: account, income_cat: income_cat} do
      transaction!(%{account_id: account.id, category_id: income_cat.id,
                     amount: Decimal.new("2000.00"), date: @today})

      {:ok, view, _html} = live(conn, ~p"/budget")
      assert has_element?(view, "[data-tbb]")
    end

    test "shows envelope list", %{conn: conn} do
      budget_envelope!(%{name: "Rent", type: "fixed"})

      {:ok, view, _html} = live(conn, ~p"/budget")
      assert has_element?(view, "[data-envelope-name='Rent']")
    end

    test "shows unassigned spending section", %{conn: conn, account: account, food_cat: food_cat} do
      transaction!(%{account_id: account.id, category_id: food_cat.id,
                     amount: Decimal.new("-50.00"), date: @today})

      {:ok, view, _html} = live(conn, ~p"/budget")
      assert has_element?(view, "[data-unassigned-section]")
    end
  end

  describe "create_envelope event" do
    test "creates a new envelope", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/budget")

      view
      |> element("button[phx-click='open_create_envelope']")
      |> render_click()

      view
      |> form("[data-form='create-envelope']", %{
        envelope: %{name: "Utilities", type: "fixed"}
      })
      |> render_submit()

      assert has_element?(view, "[data-envelope-name='Utilities']")
    end
  end

  describe "archive_envelope event" do
    test "removes envelope from active view", %{conn: conn} do
      env = budget_envelope!(%{name: "Old Envelope", type: "fixed"})
      {:ok, view, _html} = live(conn, ~p"/budget")

      assert has_element?(view, "[data-envelope-id='#{env.id}']")

      view
      |> element("[data-envelope-id='#{env.id}'] [phx-click='archive_envelope']")
      |> render_click()

      refute has_element?(view, "[data-envelope-id='#{env.id}']")
    end
  end

  describe "set_allocation event" do
    test "updates envelope allocation", %{conn: conn} do
      env = budget_envelope!(%{name: "Rent", type: "fixed"})
      {:ok, view, _html} = live(conn, ~p"/budget")

      view
      |> form("[data-envelope-id='#{env.id}'] [data-form='allocation']",
          %{amount: "1000.00"})
      |> render_submit()

      assert has_element?(view, "[data-envelope-id='#{env.id}'] [data-budgeted='1000.00']")
    end
  end

  describe "PubSub transaction update" do
    test "TBB updates when transaction PubSub arrives", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/budget")

      Phoenix.PubSub.broadcast(Xactions.PubSub, "transactions:new",
        {:transaction_created, %{amount: Decimal.new("500.00")}})

      :timer.sleep(50)
      assert has_element?(view, "[data-tbb]")
    end
  end
end
