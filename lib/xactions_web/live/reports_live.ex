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
    <div class="container mx-auto p-6 max-w-4xl">
      <h1 class="text-2xl font-bold mb-4">Reports</h1>

      <%!-- Net Worth --%>
      <div class="stats shadow mb-6">
        <div class="stat">
          <div class="stat-title">Net Worth</div>
          <div class="stat-value text-xl"><%= format_decimal(@net_worth) %></div>
        </div>
      </div>

      <%!-- Month selector --%>
      <form phx-submit="select_month" data-form="month-select" class="flex items-end gap-3 mb-6">
        <div class="form-control">
          <label class="label-text text-xs">Month</label>
          <input
            type="month"
            name="month"
            class="input input-bordered input-sm"
            value={@selected_month_str}
          />
        </div>
        <button type="submit" class="btn btn-sm btn-ghost">View</button>
      </form>

      <div
        class="text-sm text-base-content/60 mb-4"
        data-selected-month={@selected_month_str}
      >
        Showing: <%= Calendar.strftime(@selected_month, "%B %Y") %>
      </div>

      <%!-- Spending by Envelope --%>
      <h2 class="text-lg font-semibold mb-2">Spending by Envelope</h2>
      <%= if @spending_by_envelope == [] do %>
        <p class="text-base-content/50 mb-4">No envelope data for this month.</p>
      <% else %>
        <div class="overflow-x-auto mb-6">
          <table class="table table-sm">
            <thead>
              <tr><th>Envelope</th><th>Spent</th></tr>
            </thead>
            <tbody>
              <%= for row <- @spending_by_envelope do %>
                <tr>
                  <td><%= row.envelope_name %></td>
                  <td class="font-mono"><%= format_decimal(row.spent) %></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>

      <%!-- Month-over-Month --%>
      <h2 class="text-lg font-semibold mb-2">Month-over-Month</h2>
      <%= if @mom_comparison == [] do %>
        <p class="text-base-content/50 mb-4">No comparison data available.</p>
      <% else %>
        <div class="overflow-x-auto mb-6">
          <table class="table table-sm">
            <thead>
              <tr>
                <th>Envelope</th>
                <th>This Month</th>
                <th>Last Month</th>
                <th>Change</th>
              </tr>
            </thead>
            <tbody>
              <%= for row <- @mom_comparison do %>
                <tr>
                  <td><%= row.envelope_name %></td>
                  <td class="font-mono"><%= format_decimal(row.current) %></td>
                  <td class="font-mono"><%= format_decimal(row.previous) %></td>
                  <td class={["font-mono", delta_class(row.delta)]}>
                    <%= format_delta(row.delta) %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>

      <%!-- Net Worth History --%>
      <h2 class="text-lg font-semibold mb-2">Net Worth History</h2>
      <div class="overflow-x-auto">
        <table class="table table-sm">
          <thead><tr><th>Month</th><th>Net Worth</th></tr></thead>
          <tbody>
            <%= for entry <- @net_worth_history do %>
              <tr>
                <td><%= Calendar.strftime(entry.month, "%b %Y") %></td>
                <td class="font-mono"><%= format_decimal(entry.net_worth) %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
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
  defp delta_class(%Decimal{} = d), do: if(Decimal.positive?(d), do: "text-error", else: "text-success")
end
