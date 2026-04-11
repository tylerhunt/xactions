defmodule XactionsWeb.BudgetLive do
  use XactionsWeb, :live_view

  alias Xactions.Budgeting

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
     |> assign(:editing_envelope, nil)
     |> assign(:show_edit_form, false)
     |> assign(:available_edit_categories, [])
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
    category_ids =
      attrs
      |> Map.get("category_ids", [])
      |> List.wrap()
      |> Enum.map(&String.to_integer/1)

    if category_ids == [] do
      {:noreply, put_flash(socket, :error, "Select at least one category")}
    else
      case Budgeting.create_envelope_with_categories(attrs, category_ids) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(:show_create_form, false)
           |> load_budget_data(socket.assigns.date)}

        {:error, changeset} when is_struct(changeset, Ecto.Changeset) ->
          {:noreply, put_flash(socket, :error, changeset_error(changeset))}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Could not create envelope")}
      end
    end
  end

  @impl true
  def handle_event("open_edit_envelope", %{"id" => id}, socket) do
    env_id = String.to_integer(id)
    env = Enum.find(socket.assigns.envelopes, &(&1.id == env_id))

    if env do
      available = Budgeting.list_available_categories(except_envelope_id: env_id)

      {:noreply,
       socket
       |> assign(:editing_envelope, env)
       |> assign(:available_edit_categories, available)
       |> assign(:show_edit_form, true)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_edit_envelope", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_envelope, nil)
     |> assign(:show_edit_form, false)}
  end

  @impl true
  def handle_event("update_envelope", %{"envelope" => attrs}, socket) do
    category_ids =
      attrs
      |> Map.get("category_ids", [])
      |> List.wrap()
      |> Enum.map(&String.to_integer/1)

    if category_ids == [] do
      {:noreply, put_flash(socket, :error, "Select at least one category")}
    else
      env_id = attrs |> Map.get("id") |> String.to_integer()
      env = Enum.find(socket.assigns.envelopes, &(&1.id == env_id))
      do_update_envelope(socket, env, attrs, category_ids)
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

  defp do_update_envelope(socket, nil, _attrs, _ids), do: {:noreply, socket}

  defp do_update_envelope(socket, env, attrs, category_ids) do
    case Budgeting.update_envelope(env, attrs, category_ids) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:editing_envelope, nil)
         |> assign(:show_edit_form, false)
         |> load_budget_data(socket.assigns.date)}

      {:error, changeset} when is_struct(changeset, Ecto.Changeset) ->
        {:noreply, put_flash(socket, :error, changeset_error(changeset))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not update envelope")}
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
    available_categories = Budgeting.list_available_categories()

    socket
    |> assign(:envelopes, envelopes)
    |> assign(:monthly_income, monthly_income)
    |> assign(:total_allocated, total_allocated)
    |> assign(:total_spent, total_spent)
    |> assign(:unallocated, unallocated)
    |> assign(:unassigned, unassigned)
    |> assign(:available_categories, available_categories)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen">
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
            <div class="text-sm mb-1">Monthly Income</div>
            <div class="text-3xl tracking-tight">{format_money(@monthly_income)}</div>
          </div>
          <div
            data-summary="allocated"
            class="bg-white border border-black/[.08] rounded-xl p-5"
          >
            <div class="text-sm mb-1">Allocated</div>
            <div class="text-3xl tracking-tight">{format_money(@total_allocated)}</div>
          </div>
          <div
            data-summary="spent"
            class="bg-white border border-black/[.08] rounded-xl p-5"
          >
            <div class="text-sm mb-1">Spent</div>
            <div class="text-3xl tracking-tight">{format_money(@total_spent)}</div>
          </div>
          <div
            data-summary="unallocated"
            class="bg-white border border-black/[.08] rounded-xl p-5"
          >
            <div class="text-sm mb-1">Unallocated</div>
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
            <span class="text-sm">{length(@envelopes)} active</span>
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
                  <label class="text-xs block mb-1">Name</label>
                  <input
                    type="text"
                    name="envelope[name]"
                    class="w-full border border-black/[.08] rounded-lg px-3 py-2 text-sm"
                    required
                  />
                </div>
                <div>
                  <label class="text-xs block mb-1">Type</label>
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
              <div class="mb-4">
                <label class="text-xs block mb-2">
                  Categories <span class="text-[#d4183d]">*</span>
                </label>
                <div class="max-h-40 overflow-y-auto border border-black/[.08] rounded-lg p-2 flex flex-col gap-1">
                  <%= for cat <- @available_categories do %>
                    <label class="flex items-center gap-2 text-sm cursor-pointer px-1 py-0.5 hover:bg-[#ececea]/50 rounded">
                      <input
                        type="checkbox"
                        name="envelope[category_ids][]"
                        value={cat.id}
                        class="rounded"
                      />
                      {cat.name}
                    </label>
                  <% end %>
                  <%= if @available_categories == [] do %>
                    <p class="text-xs text-gray-400 px-1">No unassigned categories available.</p>
                  <% end %>
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
        <div class="bg-white border border-black/[.08] rounded-xl mb-6">
          <table class="w-full">
            <thead>
              <tr class="border-b border-black/[.08] bg-[#ececea]/30">
                <th class="text-left px-6 py-4 text-sm font-medium rounded-tl-xl">Envelope</th>
                <th class="text-right px-6 py-4 text-sm font-medium">Budgeted</th>
                <th class="text-right px-6 py-4 text-sm font-medium">Spent</th>
                <th class="text-right px-6 py-4 text-sm font-medium">Balance</th>
                <th class="px-6 py-4 text-sm font-medium">Progress</th>
                <th class="px-6 py-4 rounded-tr-xl"></th>
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
                      <div>
                        <span
                          class="font-medium"
                          data-envelope-name={env.name}
                        >
                          {env.name}
                        </span>
                        <%= if env.envelope_categories != [] do %>
                          <div class="text-xs text-gray-400 mt-0.5">
                            {Enum.map_join(env.envelope_categories, ", ", & &1.category.name)}
                          </div>
                        <% end %>
                      </div>
                      <.dropdown id={"env-menu-#{env.id}"} class="ml-1">
                        <:trigger>
                          <button class="p-1 hover:bg-[#ececea] rounded transition-colors">
                            <.icon name="hero-chevron-down" class="size-4 text-gray-400" />
                          </button>
                        </:trigger>
                        <.dropdown_item phx-click="open_edit_envelope" phx-value-id={env.id}>
                          <:icon><.icon name="hero-pencil" class="size-4" /></:icon>
                          Edit
                        </.dropdown_item>
                        <.dropdown_item variant="danger" phx-click="archive_envelope" phx-value-id={env.id}>
                          <:icon><.icon name="hero-archive-box" class="size-4" /></:icon>
                          Archive
                        </.dropdown_item>
                      </.dropdown>
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
                          class="text-xs hover:text-[#030213] px-1"
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
                      <span class="text-xs w-10 text-right">
                        {round(pct)}%
                      </span>
                    </div>
                  </td>
                  <td class="px-6 py-4"></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <%!-- Edit Envelope Form --%>
        <%= if @show_edit_form && @editing_envelope do %>
          <div class="bg-white border border-black/[.08] rounded-xl p-5 mb-6" data-edit-envelope-form>
            <h4 class="font-medium mb-4">Edit Envelope</h4>
            <form phx-submit="update_envelope" data-form="edit-envelope">
              <input type="hidden" name="envelope[id]" value={@editing_envelope.id} />
              <div class="grid grid-cols-2 gap-3 mb-4">
                <div>
                  <label class="text-xs block mb-1">Name</label>
                  <input
                    type="text"
                    name="envelope[name]"
                    value={@editing_envelope.name}
                    class="w-full border border-black/[.08] rounded-lg px-3 py-2 text-sm"
                    required
                  />
                </div>
                <div>
                  <label class="text-xs block mb-1">Type</label>
                  <select
                    name="envelope[type]"
                    class="w-full border border-black/[.08] rounded-lg px-3 py-2 text-sm bg-white"
                  >
                    <option value="fixed" selected={@editing_envelope.type == "fixed"}>Fixed</option>
                    <option value="variable" selected={@editing_envelope.type == "variable"}>
                      Variable
                    </option>
                    <option value="rollover" selected={@editing_envelope.type == "rollover"}>
                      Rollover
                    </option>
                  </select>
                </div>
              </div>
              <div class="mb-4">
                <label class="text-xs block mb-2">
                  Categories <span class="text-[#d4183d]">*</span>
                </label>
                <div class="max-h-40 overflow-y-auto border border-black/[.08] rounded-lg p-2 flex flex-col gap-1">
                  <% assigned_ids = Enum.map(@editing_envelope.envelope_categories, & &1.category_id) %>
                  <%= for cat <- @available_edit_categories do %>
                    <label class="flex items-center gap-2 text-sm cursor-pointer px-1 py-0.5 hover:bg-[#ececea]/50 rounded">
                      <input
                        type="checkbox"
                        name="envelope[category_ids][]"
                        value={cat.id}
                        checked={cat.id in assigned_ids}
                        class="rounded"
                      />
                      {cat.name}
                    </label>
                  <% end %>
                  <%= if @available_edit_categories == [] do %>
                    <p class="text-xs text-gray-400 px-1">No categories available.</p>
                  <% end %>
                </div>
              </div>
              <div class="flex gap-2">
                <button
                  type="submit"
                  class="px-4 py-2 bg-[#030213] text-white rounded-lg text-sm hover:bg-[#030213]/90 transition-colors"
                >
                  Save
                </button>
                <button
                  type="button"
                  phx-click="cancel_edit_envelope"
                  class="px-4 py-2 hover:bg-[#ececea] rounded-lg text-sm transition-colors"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        <% end %>

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
                  <span class="font-mono">
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
    |> Enum.map_join("; ", fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
  end
end
