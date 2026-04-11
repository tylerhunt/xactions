defmodule Xactions.Sync.SyncScheduler do
  @moduledoc """
  GenServer that schedules periodic syncs for all institutions.

  On startup, schedules each institution based on its `sync_interval_hours`.
  Responds to manual `{:sync_now, institution_id}` and `{:sync_all}` messages.
  On the 1st of each month, triggers `Budgeting.rollover_month/1`.
  """

  use GenServer
  require Logger

  alias Xactions.{Accounts, Repo}
  alias Xactions.Sync.SyncWorker

  @check_interval_ms :timer.hours(1)

  # --- Public API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def sync_now(institution_id) do
    GenServer.cast(__MODULE__, {:sync_now, institution_id})
  end

  def sync_all do
    GenServer.cast(__MODULE__, :sync_all)
  end

  # --- GenServer callbacks ---

  @impl true
  def init(_opts) do
    schedule_all_institutions()
    schedule_hourly_check()
    {:ok, %{last_rollover_month: nil}}
  end

  @impl true
  def handle_cast({:sync_now, institution_id}, state) do
    institution = Accounts.get_institution!(institution_id)
    Task.start(fn -> SyncWorker.sync(institution) end)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:sync_all, state) do
    Accounts.list_institutions()
    |> Enum.reject(&(&1.is_manual_only))
    |> Enum.each(fn inst ->
      Task.start(fn -> SyncWorker.sync(inst) end)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info({:sync_institution, institution_id}, state) do
    case Repo.get(Xactions.Accounts.Institution, institution_id) do
      nil ->
        {:noreply, state}

      institution ->
        maybe_sync(institution)
        schedule_institution(institution)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:hourly_check, state) do
    state = maybe_rollover_month(state)
    maybe_alert_stale_sync_errors()
    schedule_hourly_check()
    {:noreply, state}
  end

  # --- Private ---

  defp schedule_all_institutions do
    Accounts.list_institutions()
    |> Enum.reject(&(&1.is_manual_only))
    |> Enum.each(&schedule_institution/1)
  end

  defp maybe_sync(%{is_manual_only: true}), do: :ok
  defp maybe_sync(institution), do: Task.start(fn -> SyncWorker.sync(institution) end)

  defp schedule_institution(institution) do
    interval_ms = institution.sync_interval_hours * :timer.hours(1)
    Process.send_after(self(), {:sync_institution, institution.id}, interval_ms)
  end

  defp schedule_hourly_check do
    Process.send_after(self(), :hourly_check, @check_interval_ms)
  end

  defp maybe_rollover_month(%{last_rollover_month: last} = state) do
    today = Date.utc_today()

    if today.day == 1 && last != {today.year, today.month} do
      Logger.info("[SyncScheduler] Running month rollover for #{today.year}-#{today.month}")

      if Code.ensure_loaded?(Xactions.Budgeting) do
        Xactions.Budgeting.rollover_month(today)
      end

      %{state | last_rollover_month: {today.year, today.month}}
    else
      state
    end
  end

  defp maybe_alert_stale_sync_errors do
    import Ecto.Query

    cutoff = DateTime.add(DateTime.utc_now(), -3600, :second)

    stale =
      Repo.all(
        from l in Xactions.Sync.SyncLog,
          where: l.status == "error" and l.completed_at < ^cutoff,
          distinct: l.institution_id,
          order_by: [desc: l.completed_at]
      )

    Enum.each(stale, fn log ->
      Phoenix.PubSub.broadcast(
        Xactions.PubSub,
        "sync:status",
        {:sync_error_stale, log.institution_id}
      )
    end)
  end
end
