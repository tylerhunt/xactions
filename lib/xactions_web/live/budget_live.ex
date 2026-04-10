defmodule XactionsWeb.BudgetLive do
  use XactionsWeb, :live_view

  alias Xactions.{Budgeting, Transactions}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Xactions.PubSub, "transactions:new")
    end

    date = Date.utc_today()

    {:ok,
     socket
     |> assign(:date, date)
     |> assign(:editing_envelope_id, nil)
     |> assign(:show_create_form, false)
     |> load_budget_data(date)}
  end

  @impl true
  def handle_event("prev_month", _params, socket) do
    date = Date.shift(socket.assigns.date, month: -1)
    {:noreply, socket |> assign(:date, date) |> load_budget_data(date)}
  end

  @impl true
  def handle_event("next_month", _params, socket) do
    date = Date.shift(socket.assigns.date, month: 1)
    {:noreply, socket |> assign(:date, date) |> load_budget_data(date)}
  end

  @impl true
  def handle_event("edit_envelope", %{"id" => id}, socket) do
    {:noreply, assign(socket, :editing_envelope_id, String.to_integer(id))}
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, :editing_envelope_id, nil)}
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

          {:noreply,
           socket
           |> assign(:editing_envelope_id, nil)
           |> load_budget_data(socket.assigns.date)}

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
    monthly_income = Budgeting.total_income(date)
    total_allocated = Budgeting.total_allocated(date)
    total_spent = Budgeting.total_spent(date)
    unallocated = Decimal.sub(monthly_income, total_allocated)
    unassigned = Budgeting.list_unassigned_transactions(date)
    categories = Transactions.list_categories()

    socket
    |> assign(:envelopes, envelopes)
    |> assign(:monthly_income, monthly_income)
    |> assign(:total_allocated, total_allocated)
    |> assign(:total_spent, total_spent)
    |> assign(:unallocated, unallocated)
    |> assign(:unassigned, unassigned)
    |> assign(:categories, categories)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#f8f7f5]">
      <%!-- Month Navigation + Summary --%>
      <div class="max-w-7xl mx-auto px-6 py-8">
        <%!-- Month Nav --%>
        <div data-month-nav class="flex items-center gap-4 mb-6">
          <button
            phx-click="prev_month"
            class="p-2 hover:bg-[#ececea] rounded-lg transition-colors"
          >
            <.icon name="hero-chevron-left" class="size-5" />
          </button>
          <h2 class="text-3xl tracking-tight">
            {Calendar.strftime(@date, "%B %Y")}
          </h2>
          <button
            phx-click="next_month"
            class="p-2 hover:bg-[#ececea] rounded-lg transition-colors"
          >
            <.icon name="hero-chevron-right" class="size-5" />
          </button>
        </div>

        <%!-- Summary Cards --%>
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-10">
          <div
            data-summary="income"
            class="bg-white border border-black/[.08] rounded-xl p-5"
          >
            <div class="text-sm text-[#717182] mb-1">Monthly Income</div>
            <div class="text-3xl tracking-tight">{format_money(@monthly_income)}</div>
          </div>
          <div
            data-summary="allocated"
            class="bg-white border border-black/[.08] rounded-xl p-5"
          >
            <div class="text-sm text-[#717182] mb-1">Allocated</div>
            <div class="text-3xl tracking-tight">{format_money(@total_allocated)}</div>
          </div>
          <div
            data-summary="spent"
            class="bg-white border border-black/[.08] rounded-xl p-5"
          >
            <div class="text-sm text-[#717182] mb-1">Spent</div>
            <div class="text-3xl tracking-tight">{format_money(@total_spent)}</div>
          </div>
          <div
            data-summary="unallocated"
            class="bg-white border border-black/[.08] rounded-xl p-5"
          >
            <div class="text-sm text-[#717182] mb-1">Unallocated</div>
            <div
              class="text-3xl tracking-tight"
              style={"color: #{unallocated_color(@unallocated)}"}
            >
              {format_money(Decimal.abs(@unallocated))}
            </div>
          </div>
        </div>

        <%!-- Envelope Table Header --%>
        <div class="flex items-center justify-between mb-5">
          <h3 class="text-lg font-medium">Envelopes</h3>
          <div class="flex items-center gap-3">
            <span class="text-sm text-[#717182]">{length(@envelopes)} active</span>
            <button
              phx-click="open_create_envelope"
              class="px-4 py-2 bg-[#ececea] hover:bg-[#ececea]/80 rounded-lg text-sm transition-colors"
            >
              New Envelope
            </button>
          </div>
        </div>

        <%!-- Create Envelope Form --%>
        <%= if @show_create_form do %>
          <div class="bg-white border border-black/[.08] rounded-xl p-5 mb-6">
            <h4 class="font-medium mb-4">Create Envelope</h4>
            <form phx-submit="create_envelope" data-form="create-envelope">
              <div class="grid grid-cols-2 gap-3 mb-4">
                <div>
                  <label class="text-xs text-[#717182] block mb-1">Name</label>
                  <input
                    type="text"
                    name="envelope[name]"
                    class="w-full border border-black/[.08] rounded-lg px-3 py-2 text-sm"
                    required
                  />
                </div>
                <div>
                  <label class="text-xs text-[#717182] block mb-1">Type</label>
                  <select
                    name="envelope[type]"
                    class="w-full border border-black/[.08] rounded-lg px-3 py-2 text-sm bg-white"
                  >
                    <option value="fixed">Fixed</option>
                    <option value="variable">Variable</option>
                    <option value="rollover">Rollover</option>
                  </select>
                </div>
              </div>
              <div class="flex gap-2">
                <button
                  type="submit"
                  class="px-4 py-2 bg-[#030213] text-white rounded-lg text-sm hover:bg-[#030213]/90 transition-colors"
                >
                  Create
                </button>
                <button
                  type="button"
                  phx-click="cancel_create_envelope"
                  class="px-4 py-2 hover:bg-[#ececea] rounded-lg text-sm transition-colors"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        <% end %>

        <%!-- Envelope Table --%>
        <div class="bg-white border border-black/[.08] rounded-xl overflow-hidden mb-6">
          <table class="w-full">
            <thead>
              <tr class="border-b border-black/[.08] bg-[#ececea]/30">
                <th class="text-left px-6 py-4 text-sm text-[#717182] font-medium">Envelope</th>
                <th class="text-right px-6 py-4 text-sm text-[#717182] font-medium">Budgeted</th>
                <th class="text-right px-6 py-4 text-sm text-[#717182] font-medium">Spent</th>
                <th class="text-right px-6 py-4 text-sm text-[#717182] font-medium">Balance</th>
                <th class="px-6 py-4 text-sm text-[#717182] font-medium">Progress</th>
                <th class="px-6 py-4"></th>
              </tr>
            </thead>
            <tbody>
              <%= for env <- @envelopes do %>
                <% overspent = Decimal.negative?(env.remaining)
                pct = progress_pct(env.spent, env.budgeted)
                bar_color = if overspent, do: "#d4183d", else: env.color || "#3b82f6" %>
                <tr
                  data-envelope-row={env.id}
                  class="border-b border-black/[.08] last:border-b-0 hover:bg-[#ececea]/20 transition-colors"
                >
                  <td class="px-6 py-4">
                    <div class="flex items-center gap-3">
                      <div
                        data-envelope-color
                        class="w-3 h-3 rounded-full flex-shrink-0"
                        style={"background-color: #{env.color || "#3b82f6"}"}
                      >
                      </div>
                      <span
                        class="font-medium"
                        data-envelope-name={env.name}
                      >
                        {env.name}
                      </span>
                    </div>
                  </td>
                  <td class="px-6 py-4 text-right">
                    <%= if @editing_envelope_id == env.id do %>
                      <div class="flex items-center gap-1 justify-end">
                        <form
                          phx-submit="set_allocation"
                          data-form="allocation"
                        >
                          <input type="hidden" name="envelope_id" value={env.id} />
                          <input
                            type="text"
                            name="amount"
                            value={Decimal.to_string(Decimal.round(env.budgeted, 2))}
                            class="w-28 px-2 py-1 border border-black/[.08] rounded text-right text-sm"
                            autofocus
                          />
                        </form>
                        <button
                          phx-click="cancel_edit"
                          class="text-xs text-[#717182] hover:text-[#030213] px-1"
                        >
                          ✕
                        </button>
                      </div>
                    <% else %>
                      <button
                        data-budgeted
                        data-budgeted-value={Decimal.to_string(Decimal.round(env.budgeted, 2))}
                        phx-click="edit_envelope"
                        phx-value-id={env.id}
                        class="hover:bg-[#ececea]/50 px-2 py-1 rounded transition-colors text-sm"
                      >
                        {format_money(env.budgeted)}
                      </button>
                    <% end %>
                  </td>
                  <td data-spent class="px-6 py-4 text-right text-sm">{format_money(env.spent)}</td>
                  <td class="px-6 py-4 text-right text-sm">
                    <span
                      data-balance
                      style={if overspent, do: "color: #d4183d", else: ""}
                    >
                      {format_accounting(env.remaining)}
                    </span>
                  </td>
                  <td class="px-6 py-4">
                    <div class="flex items-center gap-3">
                      <div class="flex-1 h-2 bg-[#ececea] rounded-full overflow-hidden">
                        <div
                          data-progress-bar
                          class="h-full rounded-full transition-[width] duration-500"
                          style={"width: #{pct}%; background-color: #{bar_color}"}
                        >
                        </div>
                      </div>
                      <span class="text-xs text-[#717182] w-10 text-right">
                        {round(pct)}%
                      </span>
                    </div>
                  </td>
                  <td class="px-6 py-4">
                    <button
                      phx-click="archive_envelope"
                      phx-value-id={env.id}
                      class="text-xs text-[#717182] hover:text-[#d4183d] transition-colors"
                    >
                      Archive
                    </button>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <%!-- Unassigned Spending --%>
        <%= if @unassigned != [] do %>
          <div
            data-unassigned-section
            class="bg-white border border-black/[.08] rounded-xl overflow-hidden"
          >
            <div class="px-6 py-4 border-b border-black/[.08]">
              <h3 class="font-medium">Unassigned Spending</h3>
            </div>
            <div class="divide-y divide-black/[.04]">
              <%= for txn <- @unassigned do %>
                <div class="flex items-center justify-between px-6 py-3 text-sm">
                  <span>{txn.merchant_name}</span>
                  <span class="font-mono text-[#717182]">
                    {format_money(Decimal.abs(txn.amount))}
                  </span>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp progress_pct(spent, budgeted) do
    if Decimal.equal?(budgeted, Decimal.new("0")) do
      0.0
    else
      pct =
        spent
        |> Decimal.div(budgeted)
        |> Decimal.mult(Decimal.new("100"))
        |> Decimal.to_float()

      min(pct, 100.0)
    end
  end

  defp unallocated_color(%Decimal{} = d) do
    if Decimal.negative?(d), do: "#d4183d", else: "#10b981"
  end

  defp format_money(nil), do: "$0.00"

  defp format_money(%Decimal{} = d) do
    rounded = Decimal.round(d, 2)
    [integer_part, frac] = Decimal.to_string(rounded) |> String.split(".")
    formatted = integer_part |> String.to_integer() |> abs() |> Integer.to_string()

    formatted_with_commas =
      formatted
      |> String.reverse()
      |> String.graphemes()
      |> Enum.chunk_every(3)
      |> Enum.join(",")
      |> String.reverse()

    "$#{formatted_with_commas}.#{frac}"
  end

  defp format_accounting(%Decimal{} = d) do
    if Decimal.negative?(d) do
      "(#{format_money(Decimal.negate(d))})"
    else
      format_money(d)
    end
  end

  defp changeset_error(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
    |> Enum.map(fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
    |> Enum.join("; ")
  end
end
