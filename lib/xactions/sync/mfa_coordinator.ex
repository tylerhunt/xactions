defmodule Xactions.Sync.MFACoordinator do
  @moduledoc """
  GenServer that coordinates MFA resolution during sync.

  When a scraper returns `{:error, :mfa_required, type}`, the SyncWorker
  registers itself here and blocks. The user submits an MFA code via MfaLive,
  which calls `resolve_mfa/2`. The coordinator passes the code back to the
  waiting worker and resumes.

  Times out after 5 minutes with `:mfa_timeout`.
  """

  use GenServer

  @timeout_ms :timer.minutes(5)

  # --- Public API ---

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc "Called by SyncWorker to wait for an MFA code."
  def await_mfa(institution_id) do
    GenServer.call(__MODULE__, {:await_mfa, institution_id}, @timeout_ms)
  catch
    :exit, {:timeout, _} -> {:error, :mfa_timeout}
  end

  @doc "Called by MfaLive when the user submits a code."
  def resolve_mfa(institution_id, code) do
    GenServer.cast(__MODULE__, {:resolve_mfa, institution_id, code})
  end

  @doc "Called when user dismisses the MFA prompt."
  def dismiss_mfa(institution_id) do
    GenServer.cast(__MODULE__, {:dismiss_mfa, institution_id})
  end

  @doc "Returns a list of institution IDs currently awaiting MFA."
  def pending_mfa_ids do
    GenServer.call(__MODULE__, :pending_mfa_ids)
  end

  # --- GenServer callbacks ---

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:await_mfa, institution_id}, from, state) do
    timer = Process.send_after(self(), {:mfa_timeout, institution_id}, @timeout_ms)
    {:noreply, Map.put(state, institution_id, %{from: from, timer: timer})}
  end

  @impl true
  def handle_call(:pending_mfa_ids, _from, state) do
    {:reply, Map.keys(state), state}
  end

  @impl true
  def handle_cast({:resolve_mfa, institution_id, code}, state) do
    case Map.pop(state, institution_id) do
      {nil, state} ->
        {:noreply, state}

      {%{from: from, timer: timer}, state} ->
        Process.cancel_timer(timer)
        GenServer.reply(from, {:ok, code})
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:dismiss_mfa, institution_id}, state) do
    case Map.pop(state, institution_id) do
      {nil, state} ->
        {:noreply, state}

      {%{from: from, timer: timer}, state} ->
        Process.cancel_timer(timer)
        GenServer.reply(from, {:error, :mfa_dismissed})
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:mfa_timeout, institution_id}, state) do
    case Map.pop(state, institution_id) do
      {nil, state} ->
        {:noreply, state}

      {%{from: from}, state} ->
        GenServer.reply(from, {:error, :mfa_timeout})
        {:noreply, state}
    end
  end
end
