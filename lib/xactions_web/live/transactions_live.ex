defmodule XactionsWeb.TransactionsLive do
  use XactionsWeb, :live_view

  alias Xactions.{Transactions, Accounts}

  @page_size 50

  @impl true
  def mount(_params, _session, socket) do
    filters = %{}
    transactions = Transactions.list_transactions(filters)

    {:ok,
     socket
     |> assign(:filters, filters)
     |> assign(:transactions, transactions)
     |> assign(:offset, @page_size)
     |> assign(:has_more, length(transactions) == @page_size)
     |> assign(:categories, Transactions.list_categories())
     |> assign(:accounts, Accounts.list_accounts())
     |> assign(:editing_id, nil)
     |> assign(:split_transaction_id, nil)
     |> assign(:show_add_form, false)}
  end

  @impl true
  def handle_event("filter_change", %{"filters" => params}, socket) do
    filters = parse_filters(params)
    transactions = Transactions.list_transactions(Map.put(filters, :limit, @page_size))

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:transactions, transactions)
     |> assign(:offset, @page_size)
     |> assign(:has_more, length(transactions) == @page_size)
     |> assign(:split_transaction_id, nil)}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    %{filters: filters, offset: offset, transactions: existing} = socket.assigns

    more =
      Transactions.list_transactions(
        filters
        |> Map.put(:limit, @page_size)
        |> Map.put(:offset, offset)
      )

    {:noreply,
     socket
     |> assign(:transactions, existing ++ more)
     |> assign(:offset, offset + @page_size)
     |> assign(:has_more, length(more) == @page_size)}
  end

  @impl true
  def handle_event("edit_category", %{"id" => id}, socket) do
    {:noreply, assign(socket, :editing_id, String.to_integer(id))}
  end

  @impl true
  def handle_event("save_category", %{"category_id" => cat_id, "txn_id" => txn_id}, socket) do
    txn = find_transaction(socket, String.to_integer(txn_id))

    if txn do
      {:ok, _} = Transactions.update_category(txn, String.to_integer(cat_id))
      transactions = Transactions.list_transactions(socket.assigns.filters)
      {:noreply, socket |> assign(:transactions, transactions) |> assign(:editing_id, nil)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("open_split", %{"id" => id}, socket) do
    {:noreply, assign(socket, :split_transaction_id, String.to_integer(id))}
  end

  @impl true
  def handle_event("cancel_split", _params, socket) do
    {:noreply, assign(socket, :split_transaction_id, nil)}
  end

  @impl true
  def handle_event("save_split", %{"id" => txn_id, "splits" => splits}, socket) do
    txn = find_transaction(socket, to_int(txn_id))

    if txn do
      case Transactions.split_transaction(txn, splits) do
        {:ok, _} ->
          transactions = Transactions.list_transactions(socket.assigns.filters)

          {:noreply,
           socket
           |> assign(:transactions, transactions)
           |> assign(:split_transaction_id, nil)}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, split_error_message(reason))}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("open_add_transaction", _params, socket) do
    {:noreply, assign(socket, :show_add_form, true)}
  end

  @impl true
  def handle_event("cancel_add_transaction", _params, socket) do
    {:noreply, assign(socket, :show_add_form, false)}
  end

  @impl true
  def handle_event("add_manual_transaction", %{"transaction" => attrs}, socket) do
    case Transactions.add_manual_transaction(parse_transaction_attrs(attrs)) do
      {:ok, _} ->
        transactions = Transactions.list_transactions(socket.assigns.filters)

        {:noreply,
         socket
         |> assign(:transactions, transactions)
         |> assign(:show_add_form, false)}

      {:error, :not_manual_account} ->
        {:noreply, put_flash(socket, :error, "Can only add transactions to manual accounts")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, changeset_error(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#f8f7f5]">
      <div class="max-w-5xl mx-auto px-6 py-8">
        <div class="flex items-center justify-between mb-6">
          <h1 class="text-2xl tracking-tight">Transactions</h1>
          <button
            class="px-4 py-2 bg-[#030213] text-white rounded-lg text-sm hover:bg-[#030213]/90 transition-colors"
            phx-click="open_add_transaction"
          >
            Add Transaction
          </button>
        </div>

        <%!-- Filters --%>
        <form
          phx-change="filter_change"
          data-form="filters"
          class="flex flex-wrap gap-3 mb-6 items-end"
        >
          <div>
            <label class="block text-xs text-[#717182] mb-1">Account</label>
            <select
              name="filters[account_id]"
              class="border border-black/[.08] rounded-lg px-3 py-2 text-sm bg-white"
            >
              <option value="">All accounts</option>
              <%= for acct <- @accounts do %>
                <option value={acct.id} selected={Map.get(@filters, :account_id) == acct.id}>
                  {acct.name}
                </option>
              <% end %>
            </select>
          </div>
          <div>
            <label class="block text-xs text-[#717182] mb-1">From</label>
            <input
              type="date"
              name="filters[date_from]"
              class="border border-black/[.08] rounded-lg px-3 py-2 text-sm"
              value={Map.get(@filters, :date_from)}
            />
          </div>
          <div>
            <label class="block text-xs text-[#717182] mb-1">To</label>
            <input
              type="date"
              name="filters[date_to]"
              class="border border-black/[.08] rounded-lg px-3 py-2 text-sm"
              value={Map.get(@filters, :date_to)}
            />
          </div>
          <div>
            <label class="block text-xs text-[#717182] mb-1">Search</label>
            <input
              type="text"
              name="filters[query]"
              class="border border-black/[.08] rounded-lg px-3 py-2 text-sm"
              phx-debounce="300"
              value={Map.get(@filters, :query, "")}
              placeholder="Merchant name…"
            />
          </div>
        </form>

        <%!-- Add transaction form --%>
        <%= if @show_add_form do %>
          <div
            data-add-transaction-form
            class="bg-white border border-black/[.08] rounded-xl p-5 mb-6"
          >
            <h2 class="font-medium mb-4">Add Manual Transaction</h2>
            <form phx-submit="add_manual_transaction" data-form="add-transaction">
              <div class="grid grid-cols-2 gap-3">
                <div>
                  <label class="block text-xs text-[#717182] mb-1">Account</label>
                  <select
                    name="transaction[account_id]"
                    class="w-full border border-black/[.08] rounded-lg px-3 py-2 text-sm bg-white"
                  >
                    <%= for acct <- @accounts, acct.is_manual do %>
                      <option value={acct.id}>{acct.name}</option>
                    <% end %>
                  </select>
                </div>
                <div>
                  <label class="block text-xs text-[#717182] mb-1">Date</label>
                  <input
                    type="date"
                    name="transaction[date]"
                    class="w-full border border-black/[.08] rounded-lg px-3 py-2 text-sm"
                  />
                </div>
                <div>
                  <label class="block text-xs text-[#717182] mb-1">Amount</label>
                  <input
                    type="text"
                    name="transaction[amount]"
                    class="w-full border border-black/[.08] rounded-lg px-3 py-2 text-sm font-mono"
                    placeholder="-25.00"
                  />
                </div>
                <div>
                  <label class="block text-xs text-[#717182] mb-1">Merchant</label>
                  <input
                    type="text"
                    name="transaction[merchant_name]"
                    class="w-full border border-black/[.08] rounded-lg px-3 py-2 text-sm"
                  />
                </div>
                <div>
                  <label class="block text-xs text-[#717182] mb-1">Category</label>
                  <select
                    name="transaction[category_id]"
                    class="w-full border border-black/[.08] rounded-lg px-3 py-2 text-sm bg-white"
                  >
                    <option value="">Uncategorized</option>
                    <%= for cat <- @categories do %>
                      <option value={cat.id}>{cat.name}</option>
                    <% end %>
                  </select>
                </div>
              </div>
              <div class="flex gap-2 mt-4">
                <button
                  type="submit"
                  class="px-4 py-2 bg-[#030213] text-white rounded-lg text-sm hover:bg-[#030213]/90 transition-colors"
                >
                  Save
                </button>
                <button
                  type="button"
                  class="px-4 py-2 hover:bg-[#ececea] rounded-lg text-sm transition-colors text-[#717182] hover:text-[#030213]"
                  phx-click="cancel_add_transaction"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        <% end %>

        <%!-- Transaction list --%>
        <%= if @transactions == [] do %>
          <div class="text-center py-16 text-[#717182]">No transactions found.</div>
        <% else %>
          <div class="bg-white border border-black/[.08] rounded-xl overflow-hidden">
            <div class="divide-y divide-black/[.04]">
              <%= for txn <- @transactions do %>
                <.transaction_row
                  txn={txn}
                  categories={@categories}
                  editing={@editing_id == txn.id}
                  split_open={@split_transaction_id == txn.id}
                />
              <% end %>
            </div>
          </div>

          <%= if @has_more do %>
            <div class="flex justify-center mt-6">
              <button
                class="px-4 py-2 hover:bg-[#ececea] rounded-lg text-sm transition-colors text-[#717182] hover:text-[#030213]"
                phx-click="load_more"
              >
                Load more
              </button>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  defp transaction_row(assigns) do
    ~H"""
    <div
      class="px-5 py-3"
      data-txn-id={@txn.id}
      data-split={to_string(@txn.is_split)}
    >
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-3">
          <span class="text-sm text-[#717182] w-24 shrink-0">
            {@txn.date}
          </span>
          <span class="text-sm font-medium text-[#030213]" data-merchant={@txn.merchant_name}>
            {@txn.merchant_name || "—"}
          </span>
          <%= if @txn.is_split do %>
            <span
              data-split-badge
              class="text-xs font-medium px-2 py-0.5 rounded-full bg-[#717182]/10 text-[#717182]"
            >
              split
            </span>
          <% end %>
        </div>
        <div class="flex items-center gap-3">
          <%= if @txn.category && !@editing do %>
            <span class="text-xs text-[#717182]" data-category={@txn.category.name}>
              {@txn.category.name}
            </span>
          <% end %>
          <span class={["font-mono text-sm", amount_class(@txn.amount)]}>
            {format_amount(@txn.amount)}
          </span>
          <div class="flex gap-1">
            <%= unless @txn.is_split do %>
              <button
                class="px-2 py-1 hover:bg-[#ececea] rounded text-xs text-[#717182] hover:text-[#030213] transition-colors"
                phx-click="edit_category"
                phx-value-id={@txn.id}
              >
                Cat
              </button>
              <button
                class="px-2 py-1 hover:bg-[#ececea] rounded text-xs text-[#717182] hover:text-[#030213] transition-colors"
                phx-click="open_split"
                phx-value-id={@txn.id}
              >
                Split
              </button>
            <% end %>
          </div>
        </div>
      </div>

      <%!-- Inline category edit --%>
      <%= if @editing do %>
        <form
          phx-submit="save_category"
          data-split-form={@txn.id}
          class="mt-2 flex gap-2 items-center"
        >
          <input type="hidden" name="txn_id" value={@txn.id} />
          <select
            name="category_id"
            class="border border-black/[.08] rounded-lg px-3 py-1.5 text-sm bg-white"
          >
            <option value="">Uncategorized</option>
            <%= for cat <- @categories do %>
              <option value={cat.id} selected={@txn.category_id == cat.id}>{cat.name}</option>
            <% end %>
          </select>
          <button
            type="submit"
            class="px-3 py-1.5 bg-[#030213] text-white rounded-lg text-xs hover:bg-[#030213]/90 transition-colors"
          >
            Save
          </button>
        </form>
      <% end %>

      <%!-- Split editor --%>
      <%= if @split_open do %>
        <div class="mt-2 p-3 bg-[#ececea]/50 rounded-lg" data-split-editor={@txn.id}>
          <p class="text-xs text-[#717182] mb-2">
            Split total: {format_amount(@txn.amount)}
          </p>
          <button
            class="px-3 py-1.5 bg-[#030213] text-white rounded-lg text-xs hover:bg-[#030213]/90 transition-colors"
            phx-click="save_split"
            phx-value-id={@txn.id}
          >
            Save split
          </button>
          <button
            class="px-3 py-1.5 hover:bg-[#ececea] rounded-lg text-xs text-[#717182] hover:text-[#030213] transition-colors ml-2"
            phx-click="cancel_split"
          >
            Cancel
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  defp parse_filters(params) do
    %{}
    |> maybe_put(:account_id, params["account_id"], &parse_int_or_nil/1)
    |> maybe_put(:category_id, params["category_id"], &parse_int_or_nil/1)
    |> maybe_put(:date_from, params["date_from"], &parse_date_or_nil/1)
    |> maybe_put(:date_to, params["date_to"], &parse_date_or_nil/1)
    |> maybe_put(:query, params["query"], &nonempty_string/1)
  end

  defp maybe_put(map, _key, nil, _fun), do: map
  defp maybe_put(map, _key, "", _fun), do: map

  defp maybe_put(map, key, val, fun) do
    case fun.(val) do
      nil -> map
      parsed -> Map.put(map, key, parsed)
    end
  end

  defp parse_int_or_nil(v) when is_binary(v) and v != "" do
    case Integer.parse(v) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp parse_int_or_nil(_), do: nil

  defp parse_date_or_nil(v) when is_binary(v) and v != "" do
    case Date.from_iso8601(v) do
      {:ok, d} -> d
      _ -> nil
    end
  end

  defp parse_date_or_nil(_), do: nil
  defp nonempty_string(""), do: nil
  defp nonempty_string(v), do: v

  defp find_transaction(socket, id) do
    Enum.find(socket.assigns.transactions, &(&1.id == id))
  end

  defp to_int(v) when is_integer(v), do: v
  defp to_int(v) when is_binary(v), do: String.to_integer(v)

  defp split_error_message(:min_splits), do: "At least 2 splits are required"

  defp split_error_message(:amount_mismatch),
    do: "Split amounts must sum to the transaction total"

  defp split_error_message(_), do: "Could not save split"

  defp changeset_error(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
    |> Enum.map(fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
    |> Enum.join("; ")
  end

  defp format_amount(%Decimal{} = amount) do
    "$#{Decimal.to_string(Decimal.round(Decimal.abs(amount), 2))}"
  end

  defp amount_class(%Decimal{} = amount) do
    if Decimal.negative?(amount), do: "text-[#d4183d]", else: "text-[#10b981]"
  end

  defp parse_transaction_attrs(attrs) when is_map(attrs) do
    %{
      account_id: parse_int_or_nil(attrs["account_id"]),
      category_id: parse_int_or_nil(attrs["category_id"]),
      date: parse_date_or_nil(attrs["date"]),
      amount: parse_decimal_attr(attrs["amount"]),
      merchant_name: attrs["merchant_name"],
      is_manual: true
    }
  end

  defp parse_decimal_attr(v) when is_binary(v) and v != "" do
    case Decimal.parse(v) do
      {d, ""} -> d
      _ -> nil
    end
  end

  defp parse_decimal_attr(_), do: nil
end
