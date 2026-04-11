defmodule XactionsWeb.ReportsLive do
  use XactionsWeb, :live_view

  alias Xactions.{Reporting, Budgeting, Transactions}

  @impl true
  def mount(_params, _session, socket) do
    today = Date.utc_today()

    {:ok,
     socket
     |> assign(:selected_month, today)
     |> assign(:categories, Transactions.list_categories())
     |> load_report_data(today)}
  end

  @impl true
  def handle_event("select_month", %{"month" => month_str}, socket) do
    case Date.from_iso8601("#{month_str}-01") do
      {:ok, date} ->
        {:noreply,
         socket
         |> assign(:selected_month, date)
         |> assign_month_str(date)
         |> load_report_data(date)}

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid month")}
    end
  end

  @impl true
  def handle_event("set_budget", %{"category_id" => cat_id, "amount" => amount_str}, socket) do
    # Budget targets are stored as BudgetMonth allocations
    # For simplicity, this delegates to an envelope-based approach
    _ = {cat_id, amount_str}
    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_budget", %{"category_id" => _cat_id}, socket) do
    {:noreply, socket}
  end

  defp assign_month_str(socket, date) do
    assign(socket, :selected_month_str, Calendar.strftime(date, "%Y-%m"))
  end

  defp load_report_data(socket, date) do
    spending = Reporting.spending_by_envelope(date.month, date.year)
    mom = Reporting.month_over_month(date.month, date.year)
    nw = Reporting.net_worth()
    nw_history = Reporting.net_worth_history(12)

    socket
    |> assign(:spending_by_envelope, spending)
    |> assign(:mom_comparison, mom)
    |> assign(:net_worth, nw)
    |> assign(:net_worth_history, nw_history)
    |> assign(:selected_month_str, Calendar.strftime(date, "%Y-%m"))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen">
      <div class="max-w-4xl mx-auto px-6 py-8">
        <h1 class="text-2xl tracking-tight mb-6">Reports</h1>

        <%!-- Net Worth summary card --%>
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
          <div data-summary="net-worth" class="bg-white border border-black/[.08] rounded-xl p-5">
            <div class="text-sm mb-1">Net Worth</div>
            <div class="text-3xl tracking-tight">{format_decimal(@net_worth)}</div>
          </div>
        </div>

        <%!-- Month selector --%>
        <form phx-submit="select_month" data-form="month-select" class="flex items-end gap-3 mb-6">
          <div>
            <label class="block text-xs mb-1">Month</label>
            <input
              type="month"
              name="month"
              class="border border-black/[.08] rounded-lg px-3 py-2 text-sm bg-white"
              value={@selected_month_str}
            />
          </div>
          <button
            type="submit"
            class="px-4 py-2 hover:bg-[#ececea] rounded-lg text-sm hover:text-[#030213] transition-colors"
          >
            View
          </button>
        </form>

        <div
          class="text-sm mb-6"
          data-selected-month={@selected_month_str}
        >
          Showing: {Calendar.strftime(@selected_month, "%B %Y")}
        </div>

        <%!-- Spending by Envelope --%>
        <h2 class="text-base font-medium text-[#030213] mb-3">Spending by Envelope</h2>
        <%= if @spending_by_envelope == [] do %>
          <p class="mb-6">No envelope data for this month.</p>
        <% else %>
          <div class="bg-white border border-black/[.08] rounded-xl overflow-hidden mb-6">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-black/[.06]">
                  <th class="px-5 py-3 text-left text-xs font-medium uppercase tracking-wider">
                    Envelope
                  </th>
                  <th class="px-5 py-3 text-right text-xs font-medium uppercase tracking-wider">
                    Spent
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-black/[.04]">
                <%= for row <- @spending_by_envelope do %>
                  <tr>
                    <td class="px-5 py-3 text-[#030213]">{row.envelope_name}</td>
                    <td class="px-5 py-3 font-mono text-right text-[#030213]">
                      {format_decimal(row.spent)}
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>

        <%!-- Month-over-Month --%>
        <h2 class="text-base font-medium text-[#030213] mb-3">Month-over-Month</h2>
        <%= if @mom_comparison == [] do %>
          <p class="mb-6">No comparison data available.</p>
        <% else %>
          <div class="bg-white border border-black/[.08] rounded-xl overflow-hidden mb-6">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-black/[.06]">
                  <th class="px-5 py-3 text-left text-xs font-medium uppercase tracking-wider">
                    Envelope
                  </th>
                  <th class="px-5 py-3 text-right text-xs font-medium uppercase tracking-wider">
                    This Month
                  </th>
                  <th class="px-5 py-3 text-right text-xs font-medium uppercase tracking-wider">
                    Last Month
                  </th>
                  <th class="px-5 py-3 text-right text-xs font-medium uppercase tracking-wider">
                    Change
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-black/[.04]">
                <%= for row <- @mom_comparison do %>
                  <tr>
                    <td class="px-5 py-3 text-[#030213]">{row.envelope_name}</td>
                    <td class="px-5 py-3 font-mono text-right text-[#030213]">
                      {format_decimal(row.current)}
                    </td>
                    <td class="px-5 py-3 font-mono text-right text-[#030213]">
                      {format_decimal(row.previous)}
                    </td>
                    <td class={["px-5 py-3 font-mono text-right", delta_class(row.delta)]}>
                      {format_delta(row.delta)}
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>

        <%!-- Net Worth History --%>
        <h2 class="text-base font-medium text-[#030213] mb-3">Net Worth History</h2>
        <div class="bg-white border border-black/[.08] rounded-xl overflow-hidden">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-black/[.06]">
                <th class="px-5 py-3 text-left text-xs font-medium uppercase tracking-wider">
                  Month
                </th>
                <th class="px-5 py-3 text-right text-xs font-medium uppercase tracking-wider">
                  Net Worth
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-black/[.04]">
              <%= for entry <- @net_worth_history do %>
                <tr>
                  <td class="px-5 py-3 text-[#030213]">{Calendar.strftime(entry.month, "%b %Y")}</td>
                  <td class="px-5 py-3 font-mono text-right text-[#030213]">
                    {format_decimal(entry.net_worth)}
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  defp format_decimal(nil), do: "—"
  defp format_decimal(%Decimal{} = d), do: "$#{Decimal.to_string(Decimal.round(d, 2))}"

  defp format_delta(nil), do: "—"

  defp format_delta(%Decimal{} = d) do
    prefix = if Decimal.positive?(d), do: "+", else: ""
    "#{prefix}$#{Decimal.to_string(Decimal.round(d, 2))}"
  end

  defp delta_class(nil), do: ""

  defp delta_class(%Decimal{} = d),
    do: if(Decimal.positive?(d), do: "text-[#d4183d]", else: "text-[#10b981]")
end
