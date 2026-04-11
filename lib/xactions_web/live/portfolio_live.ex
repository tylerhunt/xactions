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
    <div class="min-h-screen">
      <div class="max-w-4xl mx-auto px-6 py-8">
        <h1 class="text-2xl tracking-tight mb-6">Portfolio</h1>

        <%= if @is_stale do %>
          <div
            class="border-l-4 border-[#f59e0b] bg-[#f59e0b]/5 rounded-lg px-4 py-3 text-sm text-[#030213] mb-6"
            data-price-stale
          >
            Price data may be outdated — last updated {format_datetime(@price_as_of)}
          </div>
        <% end %>

        <%!-- Summary cards --%>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
          <div data-summary="total-value" class="bg-white border border-black/[.08] rounded-xl p-5">
            <div class="text-sm mb-1">Total Value</div>
            <div class="text-2xl tracking-tight">{format_decimal(@total_value)}</div>
          </div>
          <div data-summary="cost-basis" class="bg-white border border-black/[.08] rounded-xl p-5">
            <div class="text-sm mb-1">Cost Basis</div>
            <div class="text-2xl tracking-tight">{format_decimal(@total_cost_basis)}</div>
          </div>
          <div data-summary="gain-loss" class="bg-white border border-black/[.08] rounded-xl p-5">
            <div class="text-sm mb-1">Unrealized Gain/Loss</div>
            <div class={["text-2xl tracking-tight", gain_loss_class(@total_gain_loss)]}>
              {format_decimal(@total_gain_loss)}
            </div>
          </div>
        </div>

        <%!-- Period selector --%>
        <div class="flex gap-2 mb-6">
          <%= for {label, period} <- [{"1W", :w1}, {"1M", :m1}, {"3M", :m3}, {"1Y", :y1}, {"All", :all}] do %>
            <button
              class={[
                "px-3 py-1.5 rounded-lg text-sm transition-colors",
                if(@period == period,
                  do: "bg-[#030213] text-white",
                  else: "hover:bg-[#ececea] hover:text-[#030213]"
                )
              ]}
              phx-click="set_period"
              phx-value-period={period}
              data-period={period}
              data-period-btn
              data-active={to_string(@period == period)}
            >
              {label}
            </button>
          <% end %>
        </div>

        <%!-- Holdings list --%>
        <%= if @holdings == [] do %>
          <div class="text-center py-16">No holdings found.</div>
        <% else %>
          <div class="bg-white border border-black/[.08] rounded-xl overflow-hidden mb-6">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-black/[.06]">
                  <th class="px-5 py-3 text-left text-xs font-medium uppercase tracking-wider">
                    Symbol
                  </th>
                  <th class="px-5 py-3 text-left text-xs font-medium uppercase tracking-wider">
                    Name
                  </th>
                  <th class="px-5 py-3 text-right text-xs font-medium uppercase tracking-wider">
                    Shares
                  </th>
                  <th class="px-5 py-3 text-right text-xs font-medium uppercase tracking-wider">
                    Price
                  </th>
                  <th class="px-5 py-3 text-right text-xs font-medium uppercase tracking-wider">
                    Value
                  </th>
                  <th class="px-5 py-3 text-right text-xs font-medium uppercase tracking-wider">
                    Gain/Loss
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-black/[.04]">
                <%= for holding <- @holdings do %>
                  <tr data-symbol={holding.symbol} class="hover:bg-[#f8f7f5]/50">
                    <td class="px-5 py-3 font-mono font-semibold text-[#030213]">{holding.symbol}</td>
                    <td class="px-5 py-3 text-[#030213]">{holding.name}</td>
                    <td class="px-5 py-3 font-mono text-right text-[#030213]">
                      {format_decimal(holding.quantity)}
                    </td>
                    <td class="px-5 py-3 font-mono text-right text-[#030213]">
                      {format_decimal(holding.current_price)}
                    </td>
                    <td class="px-5 py-3 font-mono text-right text-[#030213]">
                      {format_decimal(holding.current_value)}
                    </td>
                    <td class={[
                      "px-5 py-3 font-mono text-right",
                      gain_loss_class(holding.unrealized_gain_loss)
                    ]}>
                      {format_decimal(holding.unrealized_gain_loss)}
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>

          <%!-- Allocation breakdown --%>
          <h2 class="text-base font-medium text-[#030213] mb-3">Allocation</h2>
          <div class="bg-white border border-black/[.08] rounded-xl p-5 space-y-3">
            <%= for item <- @allocation do %>
              <div class="flex items-center gap-3">
                <span class="w-32 text-sm text-[#030213] capitalize">{item.class}</span>
                <div class="flex-1 bg-[#ececea] rounded h-2">
                  <div class="bg-[#030213] rounded h-2" style={"width: #{item.pct}%"}></div>
                </div>
                <span class="text-sm w-16 text-right">
                  {:erlang.float_to_binary(item.pct, decimals: 1)}%
                </span>
                <span class="font-mono text-sm text-[#030213] w-24 text-right">
                  {format_decimal(item.value)}
                </span>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
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

  defp gain_loss_class(%Decimal{} = d),
    do: if(Decimal.negative?(d), do: "text-[#d4183d]", else: "text-[#10b981]")
end
