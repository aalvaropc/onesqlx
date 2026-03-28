defmodule OnesqlxWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use OnesqlxWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :wide, :boolean, default: false, doc: "use wider max-width for the content area"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div :if={@current_scope && @current_scope.user} class="flex h-screen">
      <nav class="w-56 flex-shrink-0 border-r border-base-300 flex flex-col bg-base-200">
        <div class="p-4 border-b border-base-300">
          <a href="/" class="flex items-center gap-2">
            <img src={~p"/images/logo.svg"} width="28" />
            <span class="text-sm font-bold">OneSQLx</span>
          </a>
          <p :if={@current_scope.workspace} class="text-xs text-base-content/50 mt-1 truncate">
            {@current_scope.workspace.name}
          </p>
        </div>
        <div class="flex-1 overflow-y-auto p-2 space-y-1">
          <.nav_link href={~p"/sql-editor"} icon="hero-command-line" label="SQL Editor" />
          <.nav_link href={~p"/saved-queries"} icon="hero-bookmark" label="Saved Queries" />
          <.nav_link href={~p"/dashboards"} icon="hero-chart-bar-square" label="Dashboards" />
          <.nav_link href={~p"/schedules"} icon="hero-clock" label="Schedules" />
          <.nav_link href={~p"/data-sources"} icon="hero-circle-stack" label="Data Sources" />
          <.nav_link href={~p"/analytics"} icon="hero-chart-pie" label="Analytics" />
        </div>
        <div class="p-2 border-t border-base-300 space-y-1">
          <.nav_link href={~p"/workspace/settings"} icon="hero-cog-6-tooth" label="Workspace" />
          <.nav_link href={~p"/settings/api-tokens"} icon="hero-key" label="API Tokens" />
          <.nav_link href={~p"/users/settings"} icon="hero-user" label="Account" />
          <div class="px-3 py-1">
            <.link
              href={~p"/users/log-out"}
              method="delete"
              class="text-xs text-base-content/50 hover:text-error"
            >
              Sign Out
            </.link>
          </div>
        </div>
      </nav>
      <div class="flex-1 flex flex-col overflow-hidden">
        <main class="flex-1 overflow-auto px-4 py-6 sm:px-6 lg:px-8">
          <div class={["mx-auto space-y-4", (@wide && "max-w-7xl") || "max-w-5xl"]}>
            {render_slot(@inner_block)}
          </div>
        </main>
      </div>
    </div>

    <div :if={!@current_scope || !@current_scope.user}>
      <header class="navbar px-4 sm:px-6 lg:px-8">
        <div class="flex-1">
          <a href="/" class="flex-1 flex w-fit items-center gap-2">
            <img src={~p"/images/logo.svg"} width="36" />
            <span class="text-sm font-semibold">OneSQLx</span>
          </a>
        </div>
        <div class="flex-none">
          <ul class="flex flex-column px-1 space-x-4 items-center">
            <li>
              <a href="https://github.com/aalvaropc/onesqlx" class="btn btn-ghost">GitHub</a>
            </li>
            <li>
              <.theme_toggle />
            </li>
          </ul>
        </div>
      </header>

      <main class="px-4 py-20 sm:px-6 lg:px-8">
        <div class={["mx-auto space-y-4", (@wide && "max-w-7xl") || "max-w-2xl"]}>
          {render_slot(@inner_block)}
        </div>
      </main>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  defp nav_link(assigns) do
    ~H"""
    <.link
      navigate={@href}
      class="flex items-center gap-2 px-3 py-2 rounded-lg text-sm hover:bg-base-300 transition-colors"
    >
      <.icon name={@icon} class="size-4" />
      <span>{@label}</span>
    </.link>
    """
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
