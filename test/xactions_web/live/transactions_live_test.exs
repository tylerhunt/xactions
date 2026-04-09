defmodule XactionsWeb.TransactionsLiveTest do
  use XactionsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Xactions.Fixtures

  setup %{conn: conn} do
    inst = institution!(%{is_manual_only: true})
    account = account!(%{institution_id: inst.id, is_manual: true})
    category = category!(%{name: "Food"})
    {:ok, conn: authenticated_conn(conn), account: account, category: category}
  end

  describe "mount" do
    test "renders transaction list", %{conn: conn, account: account} do
      transaction!(%{account_id: account.id, merchant_name: "Whole Foods"})
      {:ok, view, _html} = live(conn, ~p"/transactions")
      assert has_element?(view, "[data-merchant='Whole Foods']")
    end

    test "renders empty state when no transactions", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/transactions")
      assert html =~ "No transactions"
    end
  end

  describe "filter_change event" do
    test "filters transactions by account", %{conn: conn, account: account} do
      t = transaction!(%{account_id: account.id, merchant_name: "Target"})
      inst2 = institution!()
      account2 = account!(%{institution_id: inst2.id})
      _other = transaction!(%{account_id: account2.id, merchant_name: "Shell"})

      {:ok, view, _html} = live(conn, ~p"/transactions")

      view
      |> form("[data-form='filters']", %{filters: %{account_id: account.id}})
      |> render_change()

      assert has_element?(view, "[data-merchant='Target']")
      refute has_element?(view, "[data-merchant='Shell']")

      _ = t
    end
  end

  describe "edit_category event" do
    test "updates transaction category", %{conn: conn, account: account, category: category} do
      txn = transaction!(%{account_id: account.id, merchant_name: "Starbucks"})
      {:ok, view, _html} = live(conn, ~p"/transactions")

      view
      |> element("[data-txn-id='#{txn.id}'] [phx-click='edit_category']")
      |> render_click()

      view
      |> form("[data-split-form='#{txn.id}']", %{category_id: category.id})
      |> render_submit()

      assert has_element?(view, "[data-txn-id='#{txn.id}'] [data-category='#{category.name}']")
    end
  end

  describe "open_split and save_split events" do
    test "saves valid transaction split", %{conn: conn, account: account, category: category} do
      cat2 = category!(%{name: "Health"})
      txn = transaction!(%{account_id: account.id, amount: Decimal.new("-50.00")})

      {:ok, view, _html} = live(conn, ~p"/transactions")

      view
      |> element("[data-txn-id='#{txn.id}'] [phx-click='open_split']")
      |> render_click()

      assert has_element?(view, "[data-split-editor='#{txn.id}']")

      view
      |> element("[data-split-editor='#{txn.id}'] [phx-click='save_split']")
      |> render_click(%{
        "id" => txn.id,
        "splits" => [
          %{"category_id" => category.id, "amount" => "-30.00"},
          %{"category_id" => cat2.id, "amount" => "-20.00"}
        ]
      })

      assert has_element?(view, "[data-txn-id='#{txn.id}'][data-split='true']")
    end

    test "shows error when split amounts don't sum", %{conn: conn, account: account, category: category} do
      cat2 = category!(%{name: "Health"})
      txn = transaction!(%{account_id: account.id, amount: Decimal.new("-50.00")})

      {:ok, view, _html} = live(conn, ~p"/transactions")

      view
      |> element("[data-txn-id='#{txn.id}'] [phx-click='open_split']")
      |> render_click()

      view
      |> element("[data-split-editor='#{txn.id}'] [phx-click='save_split']")
      |> render_click(%{
        "id" => txn.id,
        "splits" => [
          %{"category_id" => category.id, "amount" => "-30.00"},
          %{"category_id" => cat2.id, "amount" => "-10.00"}
        ]
      })

      assert has_element?(view, "[data-split-editor='#{txn.id}']")
    end

    test "cancel_split closes the editor", %{conn: conn, account: account} do
      txn = transaction!(%{account_id: account.id})

      {:ok, view, _html} = live(conn, ~p"/transactions")

      view
      |> element("[data-txn-id='#{txn.id}'] [phx-click='open_split']")
      |> render_click()

      assert has_element?(view, "[data-split-editor='#{txn.id}']")

      view |> element("[phx-click='cancel_split']") |> render_click()

      refute has_element?(view, "[data-split-editor='#{txn.id}']")
    end
  end

  describe "add_manual_transaction event" do
    test "adds a transaction to a manual account", %{conn: conn, account: account, category: category} do
      {:ok, view, _html} = live(conn, ~p"/transactions")

      view
      |> element("button[phx-click='open_add_transaction']")
      |> render_click()

      view
      |> form("[data-form='add-transaction']", %{
        transaction: %{
          account_id: account.id,
          category_id: category.id,
          date: Date.utc_today(),
          amount: "-25.00",
          merchant_name: "Manual Purchase"
        }
      })
      |> render_submit()

      assert has_element?(view, "[data-merchant='Manual Purchase']")
    end
  end

  describe "load_more event" do
    test "appends next page of results", %{conn: conn, account: account} do
      for i <- 1..55 do
        transaction!(%{account_id: account.id, merchant_name: "Store #{i}"})
      end

      {:ok, view, _html} = live(conn, ~p"/transactions")

      initial_html = render(view)
      initial_count = length(Regex.scan(~r/data-merchant=/, initial_html))
      assert initial_count == 50
      assert has_element?(view, "[phx-click='load_more']")

      view |> element("[phx-click='load_more']") |> render_click()

      final_html = render(view)
      final_count = length(Regex.scan(~r/data-merchant=/, final_html))
      assert final_count == 55
    end
  end
end
