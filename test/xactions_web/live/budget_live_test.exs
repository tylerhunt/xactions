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

    {:ok,
     conn: authenticated_conn(conn), account: account, income_cat: income_cat, food_cat: food_cat}
  end

  describe "mount" do
    test "renders budget page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/budget")
      assert html =~ "Budget"
    end

    test "shows envelope list", %{conn: conn} do
      budget_envelope!(%{name: "Rent", type: "fixed"})

      {:ok, view, _html} = live(conn, ~p"/budget")
      assert has_element?(view, "[data-envelope-name='Rent']")
    end

    test "shows unassigned spending section", %{conn: conn, account: account, food_cat: food_cat} do
      transaction!(%{
        account_id: account.id,
        category_id: food_cat.id,
        amount: Decimal.new("-50.00"),
        date: @today
      })

      {:ok, view, _html} = live(conn, ~p"/budget")
      assert has_element?(view, "[data-unassigned-section]")
    end
  end

  describe "summary cards" do
    test "shows monthly income card", %{conn: conn, account: account, income_cat: income_cat} do
      transaction!(%{
        account_id: account.id,
        category_id: income_cat.id,
        amount: Decimal.new("3000.00"),
        date: @today
      })

      {:ok, view, _html} = live(conn, ~p"/budget")
      assert has_element?(view, "[data-summary='income']")
      assert element(view, "[data-summary='income']") |> render() =~ "3,000"
    end

    test "shows allocated card", %{conn: conn} do
      env = budget_envelope!(%{name: "Rent", type: "fixed"})

      budget_month!(%{
        budget_envelope_id: env.id,
        month: @today.month,
        year: @today.year,
        allocated_amount: Decimal.new("1200.00")
      })

      {:ok, view, _html} = live(conn, ~p"/budget")
      assert has_element?(view, "[data-summary='allocated']")
      assert element(view, "[data-summary='allocated']") |> render() =~ "1,200"
    end

    test "shows spent card", %{conn: conn, account: account, food_cat: food_cat} do
      env = budget_envelope!(%{name: "Food", type: "variable"})
      envelope_category!(%{budget_envelope_id: env.id, category_id: food_cat.id})

      transaction!(%{
        account_id: account.id,
        category_id: food_cat.id,
        amount: Decimal.new("-75.00"),
        date: @today
      })

      {:ok, view, _html} = live(conn, ~p"/budget")
      assert has_element?(view, "[data-summary='spent']")
      assert element(view, "[data-summary='spent']") |> render() =~ "75"
    end

    test "shows unallocated card", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/budget")
      assert has_element?(view, "[data-summary='unallocated']")
    end

    test "unallocated card has red style when over-allocated",
         %{conn: conn, account: account, income_cat: income_cat} do
      # Income $500, allocate $800 → unallocated = -$300
      transaction!(%{
        account_id: account.id,
        category_id: income_cat.id,
        amount: Decimal.new("500.00"),
        date: @today
      })

      env = budget_envelope!(%{name: "Rent", type: "fixed"})

      budget_month!(%{
        budget_envelope_id: env.id,
        month: @today.month,
        year: @today.year,
        allocated_amount: Decimal.new("800.00")
      })

      {:ok, view, _html} = live(conn, ~p"/budget")
      html = element(view, "[data-summary='unallocated']") |> render()
      assert html =~ "#d4183d"
    end

    test "unallocated card has green style when positive",
         %{conn: conn, account: account, income_cat: income_cat} do
      transaction!(%{
        account_id: account.id,
        category_id: income_cat.id,
        amount: Decimal.new("2000.00"),
        date: @today
      })

      env = budget_envelope!(%{name: "Rent", type: "fixed"})

      budget_month!(%{
        budget_envelope_id: env.id,
        month: @today.month,
        year: @today.year,
        allocated_amount: Decimal.new("500.00")
      })

      {:ok, view, _html} = live(conn, ~p"/budget")
      html = element(view, "[data-summary='unallocated']") |> render()
      assert html =~ "#10b981"
    end
  end

  describe "month navigation" do
    test "renders month navigation container", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/budget")
      assert has_element?(view, "[data-month-nav]")
    end

    test "prev_month navigates to previous month", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/budget")
      prev = Date.shift(@today, month: -1)
      expected_month = Calendar.strftime(prev, "%B %Y")

      view |> element("[phx-click='prev_month']") |> render_click()

      assert render(view) =~ expected_month
    end

    test "next_month after prev_month returns to current month", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/budget")
      current_month = Calendar.strftime(@today, "%B %Y")

      view |> element("[phx-click='prev_month']") |> render_click()
      view |> element("[phx-click='next_month']") |> render_click()

      assert render(view) =~ current_month
    end

    test "summary figures reload after month navigation",
         %{conn: conn, account: account, income_cat: income_cat} do
      transaction!(%{
        account_id: account.id,
        category_id: income_cat.id,
        amount: Decimal.new("1500.00"),
        date: @today
      })

      {:ok, view, _html} = live(conn, ~p"/budget")
      assert element(view, "[data-summary='income']") |> render() =~ "1,500"

      view |> element("[phx-click='prev_month']") |> render_click()
      refute element(view, "[data-summary='income']") |> render() =~ "1,500"
    end
  end

  describe "envelope table" do
    test "shows each active envelope as a table row", %{conn: conn} do
      env = budget_envelope!(%{name: "Rent", type: "fixed"})
      {:ok, view, _html} = live(conn, ~p"/budget")
      assert has_element?(view, "[data-envelope-row='#{env.id}']")
    end

    test "each row has a color dot", %{conn: conn} do
      env = budget_envelope!(%{name: "Rent", type: "fixed"})
      {:ok, view, _html} = live(conn, ~p"/budget")
      assert has_element?(view, "[data-envelope-row='#{env.id}'] [data-envelope-color]")
    end

    test "shows envelope name with data-envelope-name attribute", %{conn: conn} do
      budget_envelope!(%{name: "Groceries", type: "variable"})
      {:ok, view, _html} = live(conn, ~p"/budget")
      assert has_element?(view, "[data-envelope-name='Groceries']")
    end

    test "shows budgeted amount in row", %{conn: conn} do
      env = budget_envelope!(%{name: "Rent", type: "fixed"})

      budget_month!(%{
        budget_envelope_id: env.id,
        month: @today.month,
        year: @today.year,
        allocated_amount: Decimal.new("1200.00")
      })

      {:ok, view, _html} = live(conn, ~p"/budget")
      html = element(view, "[data-envelope-row='#{env.id}'] [data-budgeted]") |> render()
      assert html =~ "1,200"
    end

    test "shows spent amount in row", %{conn: conn, account: account, food_cat: food_cat} do
      env = budget_envelope!(%{name: "Food", type: "variable"})
      envelope_category!(%{budget_envelope_id: env.id, category_id: food_cat.id})

      transaction!(%{
        account_id: account.id,
        category_id: food_cat.id,
        amount: Decimal.new("-90.00"),
        date: @today
      })

      {:ok, view, _html} = live(conn, ~p"/budget")
      html = element(view, "[data-envelope-row='#{env.id}'] [data-spent]") |> render()
      assert html =~ "90"
    end

    test "balance shows accounting format for overspent envelope",
         %{conn: conn, account: account, food_cat: food_cat} do
      env = budget_envelope!(%{name: "Food", type: "variable"})
      envelope_category!(%{budget_envelope_id: env.id, category_id: food_cat.id})

      budget_month!(%{
        budget_envelope_id: env.id,
        month: @today.month,
        year: @today.year,
        allocated_amount: Decimal.new("50.00")
      })

      transaction!(%{
        account_id: account.id,
        category_id: food_cat.id,
        amount: Decimal.new("-100.00"),
        date: @today
      })

      {:ok, view, _html} = live(conn, ~p"/budget")
      html = element(view, "[data-envelope-row='#{env.id}'] [data-balance]") |> render()
      assert html =~ "($50"
      assert html =~ "#d4183d"
    end

    test "progress bar present in each row", %{conn: conn} do
      env = budget_envelope!(%{name: "Rent", type: "fixed"})

      budget_month!(%{
        budget_envelope_id: env.id,
        month: @today.month,
        year: @today.year,
        allocated_amount: Decimal.new("1000.00")
      })

      {:ok, view, _html} = live(conn, ~p"/budget")
      assert has_element?(view, "[data-envelope-row='#{env.id}'] [data-progress-bar]")
    end

    test "progress bar is red when overspent",
         %{conn: conn, account: account, food_cat: food_cat} do
      env = budget_envelope!(%{name: "Food", type: "variable"})
      envelope_category!(%{budget_envelope_id: env.id, category_id: food_cat.id})

      budget_month!(%{
        budget_envelope_id: env.id,
        month: @today.month,
        year: @today.year,
        allocated_amount: Decimal.new("50.00")
      })

      transaction!(%{
        account_id: account.id,
        category_id: food_cat.id,
        amount: Decimal.new("-100.00"),
        date: @today
      })

      {:ok, view, _html} = live(conn, ~p"/budget")
      html = element(view, "[data-envelope-row='#{env.id}'] [data-progress-bar]") |> render()
      assert html =~ "#d4183d"
    end
  end

  describe "inline editing" do
    test "clicking budgeted amount shows input", %{conn: conn} do
      env = budget_envelope!(%{name: "Rent", type: "fixed"})
      {:ok, view, _html} = live(conn, ~p"/budget")

      view
      |> element("[data-envelope-row='#{env.id}'] [data-budgeted]")
      |> render_click()

      assert has_element?(view, "[data-envelope-row='#{env.id}'] input[name='amount']")
    end

    test "saving allocation via inline edit updates displayed value", %{conn: conn} do
      env = budget_envelope!(%{name: "Rent", type: "fixed"})
      {:ok, view, _html} = live(conn, ~p"/budget")

      view
      |> element("[data-envelope-row='#{env.id}'] [data-budgeted]")
      |> render_click()

      view
      |> form(
        "[data-envelope-row='#{env.id}'] [data-form='allocation']",
        %{amount: "1500.00"}
      )
      |> render_submit()

      html = element(view, "[data-envelope-row='#{env.id}'] [data-budgeted]") |> render()
      assert html =~ "1,500"
    end

    test "cancel_edit dismisses input without saving", %{conn: conn} do
      env = budget_envelope!(%{name: "Rent", type: "fixed"})
      {:ok, view, _html} = live(conn, ~p"/budget")

      view
      |> element("[data-envelope-row='#{env.id}'] [data-budgeted]")
      |> render_click()

      assert has_element?(view, "[data-envelope-row='#{env.id}'] input[name='amount']")

      view |> element("[phx-click='cancel_edit']") |> render_click()

      refute has_element?(view, "[data-envelope-row='#{env.id}'] input[name='amount']")
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

      assert has_element?(view, "[data-envelope-row='#{env.id}']")

      view
      |> element("[data-envelope-row='#{env.id}'] [phx-click='archive_envelope']")
      |> render_click()

      refute has_element?(view, "[data-envelope-row='#{env.id}']")
    end
  end

  describe "set_allocation event" do
    test "updates envelope allocation", %{conn: conn} do
      env = budget_envelope!(%{name: "Rent", type: "fixed"})
      {:ok, view, _html} = live(conn, ~p"/budget")

      view
      |> element("[data-envelope-row='#{env.id}'] [data-budgeted]")
      |> render_click()

      view
      |> form(
        "[data-envelope-row='#{env.id}'] [data-form='allocation']",
        %{amount: "1000.00"}
      )
      |> render_submit()

      html = element(view, "[data-envelope-row='#{env.id}'] [data-budgeted]") |> render()
      assert html =~ "1,000"
    end
  end

  describe "navbar" do
    test "renders sticky navbar element", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/budget")
      assert has_element?(view, "[data-navbar]")
    end
  end

  describe "PubSub transaction update" do
    test "summary reloads when transaction PubSub arrives", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/budget")

      Phoenix.PubSub.broadcast(
        Xactions.PubSub,
        "transactions:new",
        {:transaction_created, %{amount: Decimal.new("500.00")}}
      )

      :timer.sleep(50)
      assert has_element?(view, "[data-summary='income']")
    end
  end
end
