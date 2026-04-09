defmodule XactionsWeb.BudgetLive do
  use XactionsWeb, :live_view

  alias Xactions.{Budgeting, Transactions}

  @today Date.utc_today()

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Xactions.PubSub, "transactions:new")
    end

    date = @today

    {:ok,
     socket
     |> assign(:date, date)
     |> assign(:show_create_form, false)
     |> load_budget_data(date)}
  end

  @impl true
  def handle_event("open_create_envelope", _params, socket) do
    {:noreply, assign(socket, :show_create_form, true)}
  end

  @impl true
  def handle_event("cancel_create_envelope", _params, socket) do
    {:noreply, assign(socket, :show_create_form, false)}
  end

  @impl true
  def handle_event("create_envelope", %{"envelope" => attrs}, socket) do
    case Budgeting.create_envelope(attrs) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:show_create_form, false)
         |> load_budget_data(socket.assigns.date)}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, changeset_error(changeset))}
    end
  end

  @impl true
  def handle_event("archive_envelope", %{"id" => id}, socket) do
    env = Enum.find(socket.assigns.envelopes, &(&1.id == String.to_integer(id)))

    if env do
      {:ok, _} = Budgeting.archive_envelope(env)
      {:noreply, load_budget_data(socket, socket.assigns.date)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("set_allocation", %{"envelope_id" => id, "amount" => amount_str}, socket) do
    env = Enum.find(socket.assigns.envelopes, &(&1.id == String.to_integer(id)))

    if env do
      case Decimal.parse(amount_str) do
        {amount, ""} ->
          {:ok, _} = Budgeting.set_allocation(env, socket.assigns.date, amount)
          {:noreply, load_budget_data(socket, socket.assigns.date)}

        _ ->
          {:noreply, put_flash(socket, :error, "Invalid amount")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:transaction_created, _txn}, socket) do
    {:noreply, load_budget_data(socket, socket.assigns.date)}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  defp load_budget_data(socket, date) do
    envelopes = Budgeting.list_envelopes(date)
    tbb = Budgeting.to_be_budgeted(date)
    unassigned = Budgeting.list_unassigned_transactions(date)
    categories = Transactions.list_categories()

    socket
    |> assign(:envelopes, envelopes)
    |> assign(:tbb, tbb)
    |> assign(:unassigned, unassigned)
    |> assign(:categories, categories)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-6 max-w-4xl">
      <div class="flex items-center justify-between mb-4">
        <h1 class="text-2xl font-bold">Budget</h1>
        <button class="btn btn-primary btn-sm" phx-click="open_create_envelope">
          New Envelope
        </button>
      </div>

      <%!-- TBB Indicator --%>
      <div class={["stats shadow mb-6", tbb_bg(@tbb)]}>
        <div class="stat" data-tbb={format_decimal(@tbb)}>
          <div class="stat-title">To Be Budgeted</div>
          <div class={["stat-value", tbb_class(@tbb)]}>
            <%= format_decimal(@tbb) %>
          </div>
          <div class="stat-desc">
            <%= tbb_hint(@tbb) %>
          </div>
        </div>
      </div>

      <%!-- Create Envelope Form --%>
      <%= if @show_create_form do %>
        <div class="card bg-base-100 border mb-4">
          <div class="card-body py-4">
            <h2 class="font-semibold mb-2">Create Envelope</h2>
            <form phx-submit="create_envelope" data-form="create-envelope">
              <div class="grid grid-cols-2 gap-3">
                <div class="form-control">
                  <label class="label-text text-xs">Name</label>
                  <input type="text" name="envelope[name]" class="input input-bordered input-sm" required />
                </div>
                <div class="form-control">
                  <label class="label-text text-xs">Type</label>
                  <select name="envelope[type]" class="select select-bordered select-sm">
                    <option value="fixed">Fixed</option>
                    <option value="variable">Variable</option>
                    <option value="rollover">Rollover</option>
                  </select>
                </div>
              </div>
              <div class="flex gap-2 mt-3">
                <button type="submit" class="btn btn-primary btn-sm">Create</button>
                <button type="button" class="btn btn-ghost btn-sm" phx-click="cancel_create_envelope">
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

      <%!-- Envelope List --%>
      <div class="space-y-3 mb-6">
        <%= for env <- @envelopes do %>
          <div class="card bg-base-100 border" data-envelope-id={env.id} data-envelope-name={env.name}>
            <div class="card-body p-4">
              <div class="flex items-center justify-between mb-2">
                <div class="flex items-center gap-2">
                  <h3 class="font-semibold"><%= env.name %></h3>
                  <span class="badge badge-ghost badge-xs"><%= env.type %></span>
                </div>
                <button
                  class="btn btn-ghost btn-xs text-error"
                  phx-click="archive_envelope"
                  phx-value-id={env.id}
                >Archive</button>
              </div>

              <%!-- Allocation form --%>
              <form
                phx-submit="set_allocation"
                data-form="allocation"
                class="flex items-center gap-2 mb-2"
              >
                <input type="hidden" name="envelope_id" value={env.id} />
                <label class="text-xs text-base-content/60">Budgeted</label>
                <input
                  type="text"
                  name="amount"
                  class="input input-bordered input-xs w-28 font-mono"
                  value={Decimal.to_string(env.budgeted)}
                />
                <button type="submit" class="btn btn-ghost btn-xs">Set</button>
              </form>

              <%!-- Progress --%>
              <div class="flex gap-4 text-sm">
                <span>
                  Budgeted: <span class="font-mono" data-budgeted={Decimal.to_string(Decimal.round(env.budgeted, 2))}>
                    <%= format_decimal(env.budgeted) %>
                  </span>
                </span>
                <span>Spent: <span class="font-mono"><%= format_decimal(env.spent) %></span></span>
                <span class={remaining_class(env.remaining)}>
                  Remaining: <span class="font-mono"><%= format_decimal(env.remaining) %></span>
                </span>
              </div>

              <%= if not Decimal.equal?(env.budgeted, Decimal.new("0")) do %>
                <div class="w-full bg-base-200 rounded h-2 mt-2">
                  <div
                    class={["rounded h-2", progress_class(env.spent, env.budgeted)]}
                    style={"width: #{progress_pct(env.spent, env.budgeted)}%"}
                  ></div>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>

      <%!-- Unassigned Spending --%>
      <%= if @unassigned != [] do %>
        <div class="card bg-base-100 border" data-unassigned-section>
          <div class="card-body p-4">
            <h2 class="font-semibold mb-2">Unassigned Spending</h2>
            <div class="divide-y divide-base-200">
              <%= for txn <- @unassigned do %>
                <div class="flex items-center justify-between py-2 text-sm">
                  <span><%= txn.merchant_name %></span>
                  <span class="font-mono"><%= format_decimal(txn.amount) %></span>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp tbb_class(%Decimal{} = d) do
    cond do
      Decimal.equal?(d, Decimal.new("0")) -> "text-success"
      Decimal.positive?(d) -> "text-warning"
      true -> "text-error"
    end
  end

  defp tbb_bg(%Decimal{} = d) do
    cond do
      Decimal.equal?(d, Decimal.new("0")) -> ""
      Decimal.positive?(d) -> "border-warning/20"
      true -> "border-error/20"
    end
  end

  defp tbb_hint(%Decimal{} = d) do
    cond do
      Decimal.equal?(d, Decimal.new("0")) -> "Fully budgeted"
      Decimal.positive?(d) -> "Assign to envelopes"
      true -> "Over-allocated"
    end
  end

  defp remaining_class(%Decimal{} = d) do
    if Decimal.negative?(d), do: "text-error", else: ""
  end

  defp progress_pct(spent, budgeted) do
    if Decimal.equal?(budgeted, Decimal.new("0")) do
      0
    else
      pct =
        spent
        |> Decimal.div(budgeted)
        |> Decimal.mult(Decimal.new("100"))
        |> Decimal.to_float()

      min(pct, 100)
    end
  end

  defp progress_class(spent, budgeted) do
    if Decimal.compare(spent, budgeted) == :gt, do: "bg-error", else: "bg-primary"
  end

  defp format_decimal(nil), do: "—"
  defp format_decimal(%Decimal{} = d), do: "$#{Decimal.to_string(Decimal.round(d, 2))}"

  defp changeset_error(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
    |> Enum.map(fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
    |> Enum.join("; ")
  end
end
