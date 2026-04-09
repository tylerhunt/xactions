defmodule XactionsWeb.Router do
  use XactionsWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {XactionsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :authenticated do
    plug XactionsWeb.AuthPlug
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Unauthenticated routes
  scope "/", XactionsWeb do
    pipe_through :browser

    get "/login", SessionController, :new
    post "/login", SessionController, :create
    delete "/logout", SessionController, :delete
  end

  # Authenticated routes
  scope "/", XactionsWeb do
    pipe_through [:browser, :authenticated]

    live "/", DashboardLive
    live "/accounts", AccountsLive
    live "/transactions", TransactionsLive
    live "/portfolio", PortfolioLive
    live "/budget", BudgetLive
    live "/reports", ReportsLive
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:xactions, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: XactionsWeb.Telemetry
    end
  end
end
