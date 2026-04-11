defmodule XactionsWeb.AccountsLiveTest do
  use XactionsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Xactions.Fixtures

  setup %{conn: conn} do
    {:ok, conn: authenticated_conn(conn)}
  end

  describe "mount" do
    test "renders institution list", %{conn: conn} do
      inst = institution!(%{name: "Test Bank"})
      {:ok, view, _html} = live(conn, ~p"/accounts")
      assert has_element?(view, "[data-institution-id='#{inst.id}']")
    end

    test "renders add institution button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts")
      assert has_element?(view, "button", "Add Institution")
    end
  end

  describe "add_institution event" do
    test "opens add institution form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts")
      view |> element("button", "Add Institution") |> render_click()
      assert has_element?(view, "form[data-form='add-institution']")
    end
  end

  describe "save_institution event" do
    test "creates institution with valid attrs", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts")
      view |> element("button", "Add Institution") |> render_click()

      view
      |> form("form[data-form='add-institution']", %{
        institution: %{name: "New Bank", sync_method: "browser"}
      })
      |> render_submit()

      assert has_element?(view, "[data-institution-name='New Bank']")
    end

    test "shows validation errors for blank name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts")
      view |> element("button", "Add Institution") |> render_click()

      view
      |> form("form[data-form='add-institution']", %{institution: %{name: ""}})
      |> render_submit()

      assert has_element?(view, "[data-field-error]", "can't be blank")
    end
  end

  describe "remove_institution event" do
    test "deletes institution from list", %{conn: conn} do
      inst = institution!(%{name: "To Delete"})
      {:ok, view, _html} = live(conn, ~p"/accounts")

      view
      |> element("[data-institution-id='#{inst.id}'] [phx-click='remove_institution']")
      |> render_click()

      refute has_element?(view, "[data-institution-id='#{inst.id}']")
    end
  end

  describe "design system" do
    test "does not use DaisyUI component classes", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts")
      refute html =~ "card-body"
      refute html =~ "card-title"
      refute html =~ "btn-primary"
      refute html =~ "btn-ghost"
      refute html =~ "alert-error"
    end
  end

  describe "sync_now event" do
    setup do
      Ecto.Adapters.SQL.Sandbox.mode(Xactions.Repo, {:shared, self()})
      start_supervised!(Xactions.Sync.SyncScheduler)
      :ok
    end

    test "broadcasts sync:started via PubSub", %{conn: conn} do
      inst = institution!(%{scraper_module: "Xactions.FakeScraper"})
      {:ok, view, _html} = live(conn, ~p"/accounts")

      Phoenix.PubSub.subscribe(Xactions.PubSub, "sync:status")
      inst_id = inst.id

      view
      |> element("[data-institution-id='#{inst_id}'] [phx-click='sync_now']")
      |> render_click()

      assert_receive {:sync_started, ^inst_id}, 1000
      assert_receive {:sync_complete, ^inst_id}, 2000
    end
  end
end
