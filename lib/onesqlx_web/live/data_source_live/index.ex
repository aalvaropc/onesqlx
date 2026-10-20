defmodule OnesqlxWeb.DataSourceLive.Index do
  use OnesqlxWeb, :live_view

  alias Onesqlx.DataSources

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Data Sources
        <:subtitle>
          Manage your external PostgreSQL database connections.
        </:subtitle>
        <:actions>
          <.button
            :if={@current_scope.role != "viewer"}
            navigate={~p"/data-sources/new"}
            variant="primary"
          >
            <.icon name="hero-plus" class="size-4" /> New Data Source
          </.button>
        </:actions>
      </.header>

      <.table
        :if={@has_data_sources?}
        id="data-sources"
        rows={@streams.data_sources}
        row_id={fn {id, _ds} -> id end}
      >
        <:col :let={{_id, ds}} label="Name">
          <span class="flex items-center gap-3">
            <span class="object-symbol"><.icon name="hero-circle-stack" class="size-4" /></span><span class="font-medium">{ds.name}</span>
          </span>
        </:col>
        <:col :let={{_id, ds}} label="Host">
          <span class="font-mono text-xs text-muted">{ds.host}</span>
        </:col>
        <:col :let={{_id, ds}} label="Database">{ds.database_name}</:col>
        <:col :let={{_id, ds}} label="Status">
          <span class={[
            "ui-badge",
            ds.status == "connected" && "ui-badge-success",
            ds.status == "error" && "ui-badge-error",
            ds.status == "pending" && "ui-badge-warning"
          ]}>
            {ds.status}
          </span>
        </:col>
        <:col :let={{_id, ds}} label="">
          <div class="flex items-center gap-3">
            <.link
              navigate={~p"/data-sources/#{ds.id}/catalog"}
              class="ui-link ui-link-primary text-sm"
            >
              Explore
            </.link>
            <.link
              :if={@current_scope.role != "viewer"}
              navigate={~p"/data-sources/#{ds.id}/edit"}
              class="ui-link text-sm"
            >
              Edit
            </.link>
          </div>
        </:col>
      </.table>

      <div :if={!@has_data_sources?} class="empty-state">
        <.icon name="hero-circle-stack" class="size-12 text-base-content/20 mx-auto mb-4" />
        <p class="text-muted mb-2">No data sources yet</p>
        <p class="text-sm text-muted mb-4">
          Connect a PostgreSQL database to start exploring your data.
        </p>
        <.link navigate={~p"/data-sources/new"} class="ui-button ui-button-primary ui-button-sm">
          Add Data Source
        </.link>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    data_sources = DataSources.list_data_sources(socket.assigns.current_scope)

    socket =
      socket
      |> assign(:has_data_sources?, data_sources != [])
      |> stream(:data_sources, data_sources)

    {:ok, socket}
  end
end
