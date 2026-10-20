defmodule OnesqlxWeb.Layouts do
  @moduledoc "Shared application, public, and authentication layouts."
  use OnesqlxWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  attr :current_scope, :any, default: nil
  attr :wide, :boolean, default: false
  attr :mode, :string, default: "app", values: ~w(app marketing shared embed)
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <%= cond do %>
      <% @mode in ["shared", "embed"] -> %>
        <div
          id="main-content"
          class={if(@mode == "embed", do: "p-4", else: "mx-auto max-w-7xl px-4 py-8 sm:px-8")}
        >
          <header :if={@mode == "shared"} class="flex items-center justify-between mb-8 gap-4">
            <.brand />
            <.theme_toggle />
          </header>
          {render_slot(@inner_block)}
        </div>
      <% @mode == "app" && @current_scope && @current_scope.user -> %>
        <div id="application-shell" class="app-shell">
          <aside class="app-sidebar" aria-label="Main navigation">
            <.sidebar_content current_scope={@current_scope} />
          </aside>
          <dialog id="mobile-menu" class="mobile-drawer" aria-label="Main navigation">
            <button type="button" data-close-menu class="mobile-drawer-close" aria-label="Close menu">
              <.icon name="hero-x-mark" class="size-5" />
            </button>
            <.sidebar_content current_scope={@current_scope} />
          </dialog>
          <div class="app-frame">
            <header class="app-topbar">
              <div class="topbar-location">
                <button
                  id="open-navigation"
                  type="button"
                  data-open-menu
                  class="mobile-menu-button"
                  aria-label="Open menu"
                  aria-haspopup="dialog"
                  aria-controls="mobile-menu"
                >
                  <.icon name="hero-bars-3" class="size-5" />
                </button>
                <span class="topbar-workspace">
                  {(@current_scope.workspace && @current_scope.workspace.name) || "My Workspace"}
                </span>
                <.icon name="hero-chevron-right-micro" class="size-3 topbar-divider" />
                <strong data-section-title>Workspace</strong>
              </div>
              <div class="topbar-actions">
                <a
                  href="https://github.com/aalvaropc/onesqlx"
                  class="topbar-source"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  Open source
                </a>
                <.theme_toggle />
              </div>
            </header>
            <main id="main-content" class="app-main" tabindex="-1">
              <div class={["app-content", @wide && "app-content-wide"]}>
                {render_slot(@inner_block)}
              </div>
            </main>
          </div>
        </div>
      <% true -> %>
        <div class="public-site">
          <.public_header current_scope={@current_scope} />
          <main
            id="main-content"
            class={if(@mode == "marketing", do: "marketing-main", else: "auth-main")}
            tabindex="-1"
          >
            <%= if @mode == "marketing" do %>
              {render_slot(@inner_block)}
            <% else %>
              <div class="auth-layout">
                <aside class="auth-story">
                  <div>
                    <h2>Your data.<br />Your next discovery.</h2>
                    <p>
                      A focused place to explore PostgreSQL, write your next query, and share what you find.
                    </p>
                    <pre class="auth-story-sql" phx-no-curly-interpolation>SELECT possibilities
                    FROM your_data
                    WHERE curiosity = true;</pre>
                  </div>
                  <p class="auth-story-note">Open source. SQL first. Built for your team.</p>
                </aside>
                <div class="auth-form-area">
                  <div class="auth-form">{render_slot(@inner_block)}</div>
                </div>
              </div>
            <% end %>
          </main>
          <footer class="public-footer">
            <.brand />
            <div class="footer-theme"><.theme_toggle /></div>
            <p>SQL-first analytics platform. Open source under Apache 2.0.</p>
            <a href="https://github.com/aalvaropc/onesqlx" class="ui-link">
              View the source <.icon name="hero-arrow-up-right" class="size-3 inline-block" />
            </a>
          </footer>
        </div>
    <% end %>
    <.flash_group flash={@flash} />
    """
  end

  attr :class, :string, default: ""

  def brand(assigns) do
    ~H"""
    <.link href={~p"/"} class={["brand", @class]} aria-label="OneSQLx home">
      <span class="brand-mark" aria-hidden="true">
        <svg viewBox="0 0 24 24" fill="none">
          <path d="M4 6h6v6H4zM14 12h6v6h-6z" fill="currentColor" />
          <path
            d="m14 6 6 0M17 3v6M4 18h6"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
          />
        </svg>
      </span>
      <span>OneSQL<span class="brand-x">x</span></span>
    </.link>
    """
  end

  attr :current_scope, :any, default: nil

  def public_header(assigns) do
    ~H"""
    <header class="public-header">
      <.brand />
      <nav class="public-nav" aria-label="Public navigation">
        <a href="/#workflow" class="desktop-link">How it works</a>
        <a
          href="https://github.com/aalvaropc/onesqlx"
          class="desktop-link"
          target="_blank"
          rel="noopener noreferrer"
        >
          GitHub
        </a>
        <.theme_toggle />
        <%= if @current_scope && @current_scope.user do %>
          <.link
            navigate={~p"/users/settings"}
            class="desktop-link max-w-48 truncate"
            title="Account settings"
          >
            {@current_scope.user.email}
          </.link>
          <.link href={~p"/users/log-out"} method="delete" class="desktop-link">Sign out</.link>
          <.link navigate={~p"/sql-editor"} class="ui-button ui-button-primary">
            Open workspace <.icon name="hero-arrow-up-right" class="size-3.5" />
          </.link>
        <% else %>
          <.link navigate={~p"/users/log-in"}>Log in</.link>
          <.link
            navigate={~p"/users/register"}
            class="ui-button ui-button-primary"
            title="Register your workspace"
          >
            Get started <.icon name="hero-arrow-up-right" class="size-3.5" />
          </.link>
        <% end %>
      </nav>
    </header>
    """
  end

  attr :current_scope, :any, required: true

  defp sidebar_content(assigns) do
    ~H"""
    <div class="sidebar-brand"><.brand /></div>
    <.link navigate={~p"/workspace/settings"} class="workspace-selector">
      <span class="workspace-avatar" aria-hidden="true">
        {String.first((@current_scope.workspace && @current_scope.workspace.name) || "W")
        |> String.upcase()}
      </span>
      <span class="min-w-0 flex-1">
        <span class="workspace-name">
          {(@current_scope.workspace && @current_scope.workspace.name) || "My Workspace"}
        </span>
        <span class="workspace-role">{@current_scope.role || "Personal workspace"}</span>
      </span>
      <.icon name="hero-chevron-down-micro" class="size-3 text-[#a0b8ad]" />
    </.link>
    <.link navigate={~p"/search"} class="sidebar-search" data-nav-path="/search">
      <.icon name="hero-magnifying-glass" class="size-4" /> Search workspace <kbd>/</kbd>
    </.link>
    <nav class="sidebar-navigation" aria-label="Workspace navigation">
      <div class="nav-section">
        <span class="nav-section-label">Explore</span>
        <.nav_link href={~p"/sql-editor"} icon="hero-code-bracket" label="SQL Editor" />
        <.nav_link href={~p"/saved-queries"} icon="hero-bookmark" label="Saved Queries" />
        <.nav_link href={~p"/dashboards"} icon="hero-squares-2x2" label="Dashboards" />
        <.nav_link href={~p"/data-sources"} icon="hero-circle-stack" label="Data Sources" />
      </div>
      <div class="nav-section">
        <span class="nav-section-label">Observe</span>
        <.nav_link href={~p"/schedules"} icon="hero-clock" label="Schedules" />
        <.nav_link href={~p"/analytics"} icon="hero-chart-bar" label="Usage Analytics" />
        <.nav_link href={~p"/lineage"} icon="hero-share" label="Data Lineage" />
        <.nav_link href={~p"/audit"} icon="hero-clipboard-document-list" label="Audit Log" />
      </div>
      <div class="nav-section">
        <span class="nav-section-label">Workspace</span>
        <.nav_link href={~p"/workspace/settings"} icon="hero-cog-6-tooth" label="Settings & Members" />
        <.nav_link href={~p"/settings/api-tokens"} icon="hero-key" label="API Tokens" />
      </div>
    </nav>
    <div class="sidebar-account">
      <.link navigate={~p"/users/settings"} class="account-link">
        <span class="workspace-avatar" aria-hidden="true">
          {String.first(@current_scope.user.email) |> String.upcase()}
        </span>
        <span class="min-w-0">
          <span class="account-email">{@current_scope.user.email}</span><span class="workspace-role">Account settings</span>
        </span>
      </.link>
      <div class="account-actions">
        <a href="https://github.com/aalvaropc/onesqlx" target="_blank" rel="noopener noreferrer">
          OneSQLx on GitHub
        </a>
        <.link href={~p"/users/log-out"} method="delete">Sign out</.link>
      </div>
    </div>
    """
  end

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true

  defp nav_link(assigns) do
    ~H"""
    <.link navigate={@href} data-nav-path={@href} class="app-nav-link">
      <.icon name={@icon} class="size-[17px]" />
      <span>{@label}</span>
      <span class="nav-active-dot" aria-hidden="true"></span>
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

  @doc "Theme preference controls; events are handled by the bundled theme module."
  def theme_toggle(assigns) do
    ~H"""
    <div class="theme-switcher" role="group" aria-label="Color theme">
      <button
        type="button"
        data-phx-theme="system"
        aria-label="System theme"
        aria-pressed="false"
        title="Use system theme"
      >
        <.icon name="hero-computer-desktop-micro" class="size-3.5" />
      </button>
      <button
        type="button"
        data-phx-theme="light"
        aria-label="Light theme"
        aria-pressed="false"
        title="Use light theme"
      >
        <.icon name="hero-sun-micro" class="size-3.5" />
      </button>
      <button
        type="button"
        data-phx-theme="dark"
        aria-label="Dark theme"
        aria-pressed="false"
        title="Use dark theme"
      >
        <.icon name="hero-moon-micro" class="size-3.5" />
      </button>
    </div>
    """
  end
end
