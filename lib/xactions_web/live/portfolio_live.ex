defmodule XactionsWeb.PortfolioLive do
  use XactionsWeb, :live_view

  alias Xactions.Portfolio

  @stale_threshold_minutes 15

  @impl true
  def mount(_params, _session, socket) do
    holdings = Portfolio.list_holdings()
    allocation = Portfolio.get_allocation()
    price_as_of = Portfolio.oldest_price_timestamp()
    is_stale = stale?(price_as_of)

    total_value = sum_field(holdings, :current_value)
    total_cost = sum_field(holdings, :cost_basis)
    total_gain_loss = if total_value && total_cost, do: Decimal.sub(total_value, total_cost)

    {:ok,
     socket
     |> assign(:holdings, holdings)
     |> assign(:allocation, allocation)
     |> assign(:total_value, total_value)
     |> assign(:total_cost_basis, total_cost)
     |> assign(:total_gain_loss, total_gain_loss)
     |> assign(:price_as_of, price_as_of)
     |> assign(:is_stale, is_stale)
     |> assign(:period, :m1)}
  end

  @impl true
  def handle_event("set_period", %{"period" => period}, socket) do
    {:noreply, assign(socket, :period, String.to_atom(period))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-6 max-w-4xl">
      <h1 class="text-2xl font-bold mb-4">Portfolio</h1>

      <%= if @is_stale do %>
        <div class="alert alert-warning mb-4" data-price-stale>
          <span>Price data may be outdated — last updated <%= format_datetime(@price_as_of) %></span>
        </div>
      <% end %>

      <%!-- Summary bar --%>
      <div class="stats shadow mb-6">
        <div class="stat">
          <div class="stat-title">Total Value</div>
          <div class="stat-value text-lg"><%= format_decimal(@total_value) %></div>
        </div>
        <div class="stat">
          <div class="stat-title">Cost Basis</div>
          <div class="stat-value text-lg"><%= format_decimal(@total_cost_basis) %></div>
        </div>
        <div class="stat">
          <div class="stat-title">Unrealized Gain/Loss</div>
          <div class={["stat-value text-lg", gain_loss_class(@total_gain_loss)]}>
            <%= format_decimal(@total_gain_loss) %>
          </div>
        </div>
      </div>

      <%!-- Period selector --%>
      <div class="flex gap-2 mb-4">
        <%= for {label, period} <- [{"1W", :w1}, {"1M", :m1}, {"3M", :m3}, {"1Y", :y1}, {"All", :all}] do %>
          <button
            class={["btn btn-xs", @period == period && "btn-primary" || "btn-ghost"]}
            phx-click="set_period"
            phx-value-period={period}
            data-period={period}
            data-active={to_string(@period == period)}
          >
            <%= label %>
          </button>
        <% end %>
      </div>

      <%!-- Holdings list --%>
      <%= if @holdings == [] do %>
        <div class="text-center py-16 text-base-content/50">No holdings found.</div>
      <% else %>
        <div class="overflow-x-auto mb-6">
          <table class="table table-sm">
            <thead>
              <tr>
                <th>Symbol</th>
                <th>Name</th>
                <th>Shares</th>
                <th>Price</th>
                <th>Value</th>
                <th>Gain/Loss</th>
              </tr>
            </thead>
            <tbody>
              <%= for holding <- @holdings do %>
                <tr data-symbol={holding.symbol}>
                  <td class="font-mono font-semibold"><%= holding.symbol %></td>
                  <td><%= holding.name %></td>
                  <td class="font-mono"><%= format_decimal(holding.quantity) %></td>
                  <td class="font-mono"><%= format_decimal(holding.current_price) %></td>
                  <td class="font-mono"><%= format_decimal(holding.current_value) %></td>
                  <td class={["font-mono", gain_loss_class(holding.unrealized_gain_loss)]}>
                    <%= format_decimal(holding.unrealized_gain_loss) %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <%!-- Allocation breakdown --%>
        <h2 class="text-lg font-semibold mb-2">Allocation</h2>
        <div class="space-y-2">
          <%= for item <- @allocation do %>
            <div class="flex items-center gap-3">
              <span class="w-32 text-sm capitalize"><%= item.class %></span>
              <div class="flex-1 bg-base-200 rounded h-3">
                <div class="bg-primary rounded h-3" style={"width: #{item.pct}%"}></div>
              </div>
              <span class="text-sm w-16 text-right"><%= :erlang.float_to_binary(item.pct, decimals: 1) %>%</span>
              <span class="font-mono text-sm w-24 text-right"><%= format_decimal(item.value) %></span>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp stale?(nil), do: false

  defp stale?(%DateTime{} = dt) do
    diff = DateTime.diff(DateTime.utc_now(), dt, :minute)
    diff > @stale_threshold_minutes
  end

  defp sum_field(holdings, field) do
    Enum.reduce(holdings, nil, fn h, acc ->
      val = Map.get(h, field)

      cond do
        is_nil(val) -> acc
        is_nil(acc) -> val
        true -> Decimal.add(acc, val)
      end
    end)
  end

  defp format_decimal(nil), do: "—"
  defp format_decimal(%Decimal{} = d), do: "$#{Decimal.to_string(Decimal.round(d, 2))}"

  defp format_datetime(nil), do: "unknown"
  defp format_datetime(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d %H:%M UTC")

  defp gain_loss_class(nil), do: ""
  defp gain_loss_class(%Decimal{} = d), do: if(Decimal.negative?(d), do: "text-error", else: "text-success")
end
