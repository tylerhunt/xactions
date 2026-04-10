defmodule XactionsWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use XactionsWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :current_path, :string, default: nil, doc: "the current request path"

  def app(assigns) do
    ~H"""
    <header
      data-navbar
      class="sticky top-0 z-10 border-b border-black/[.08] bg-white/80 backdrop-blur-sm"
    >
      <div class="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
        <.link navigate={~p"/"} class="text-xl tracking-tight text-[#030213] font-medium">
          xactions
        </.link>
        <%!-- Desktop nav --%>
        <div class="hidden sm:flex items-center gap-1">
          <.link navigate={~p"/"} class={nav_link_class("/", @current_path)}>Dashboard</.link>
          <.link navigate={~p"/accounts"} class={nav_link_class("/accounts", @current_path)}>
            Accounts
          </.link>
          <.link navigate={~p"/transactions"} class={nav_link_class("/transactions", @current_path)}>
            Transactions
          </.link>
          <.link navigate={~p"/portfolio"} class={nav_link_class("/portfolio", @current_path)}>
            Portfolio
          </.link>
          <.link navigate={~p"/budget"} class={nav_link_class("/budget", @current_path)}>
            Budget
          </.link>
          <.link navigate={~p"/reports"} class={nav_link_class("/reports", @current_path)}>
            Reports
          </.link>
        </div>
        <div class="flex items-center gap-2">
          <%!-- User menu --%>
          <div class="relative" id="user-menu" phx-hook="Dropdown">
            <button
              class="p-2 rounded-lg hover:bg-[#ececea] transition-colors"
              id="user-menu-btn"
              phx-click={JS.toggle(to: "#user-menu-dropdown")}
            >
              <.icon name="hero-user-circle" class="size-6 text-[#717182]" />
            </button>
            <div
              id="user-menu-dropdown"
              class="hidden absolute right-0 mt-1 w-40 bg-white border border-black/[.08] rounded-xl shadow-lg z-20 py-1"
            >
              <.link
                href={~p"/logout"}
                method="delete"
                class="block px-4 py-2 text-sm text-[#717182] hover:text-[#030213] hover:bg-[#ececea]/50 transition-colors"
              >
                Sign Out
              </.link>
            </div>
          </div>
          <%!-- Mobile nav hamburger --%>
          <div class="sm:hidden relative" id="mobile-menu">
            <button
              class="p-2 rounded-lg hover:bg-[#ececea] transition-colors"
              phx-click={JS.toggle(to: "#mobile-menu-dropdown")}
            >
              <.icon name="hero-bars-3" class="size-5 text-[#717182]" />
            </button>
            <div
              id="mobile-menu-dropdown"
              class="hidden absolute right-0 mt-1 w-52 bg-white border border-black/[.08] rounded-xl shadow-lg z-20 py-1"
            >
              <.link navigate={~p"/"} class={mobile_nav_link_class("/", @current_path)}>
                Dashboard
              </.link>
              <.link
                navigate={~p"/accounts"}
                class={mobile_nav_link_class("/accounts", @current_path)}
              >
                Accounts
              </.link>
              <.link
                navigate={~p"/transactions"}
                class={mobile_nav_link_class("/transactions", @current_path)}
              >
                Transactions
              </.link>
              <.link
                navigate={~p"/portfolio"}
                class={mobile_nav_link_class("/portfolio", @current_path)}
              >
                Portfolio
              </.link>
              <.link navigate={~p"/budget"} class={mobile_nav_link_class("/budget", @current_path)}>
                Budget
              </.link>
              <.link navigate={~p"/reports"} class={mobile_nav_link_class("/reports", @current_path)}>
                Reports
              </.link>
            </div>
          </div>
        </div>
      </div>
    </header>
    <main>
      {@inner_content}
    </main>
    <.flash_group flash={@flash} />
    """
  end

  defp nav_link_class(path, current_path) do
    base = "text-sm px-3 py-2 rounded-lg transition-colors"

    if path == current_path,
      do: base <> " bg-[#ececea] text-[#030213]",
      else: base <> " text-[#717182] hover:text-[#030213] hover:bg-[#ececea]/50"
  end

  defp mobile_nav_link_class(path, current_path) do
    base = "block px-4 py-2 text-sm transition-colors"

    if path == current_path,
      do: base <> " bg-[#ececea] text-[#030213]",
      else: base <> " text-[#717182] hover:text-[#030213] hover:bg-[#ececea]/50"
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
