defmodule Xactions.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        XactionsWeb.Telemetry,
        Xactions.Repo,
        Xactions.Vault,
        {DNSCluster, query: Application.get_env(:xactions, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Xactions.PubSub},
        Xactions.Sync.MFACoordinator,
        XactionsWeb.Endpoint
      ] ++ sync_children()



    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Xactions.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  defp sync_children do
    if Application.get_env(:xactions, :start_sync_scheduler, true) do
      [Xactions.Sync.SyncScheduler]
    else
      []
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    XactionsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
