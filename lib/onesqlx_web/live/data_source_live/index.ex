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
          <.link navigate={~p"/data-sources/new"}>
            <.button variant="primary">New Data Source</.button>
          </.link>
        </:actions>
      </.header>

      <.table
        :if={@has_data_sources?}
        id="data-sources"
        rows={@streams.data_sources}
        row_id={fn {id, _ds} -> id end}
      >
        <:col :let={{_id, ds}} label="Name">{ds.name}</:col>
        <:col :let={{_id, ds}} label="Host">{ds.host}</:col>
        <:col :let={{_id, ds}} label="Database">{ds.database_name}</:col>
        <:col :let={{_id, ds}} label="Status">
          <span class={[
            "badge",
            ds.status == "connected" && "badge-success",
            ds.status == "error" && "badge-error",
            ds.status == "pending" && "badge-warning"
          ]}>
            {ds.status}
          </span>
        </:col>
      </.table>

      <div :if={!@has_data_sources?} class="text-center py-12">
        <p class="text-base-content/60">No data sources yet. Add one to get started.</p>
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
