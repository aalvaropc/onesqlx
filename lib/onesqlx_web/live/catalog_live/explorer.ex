defmodule OnesqlxWeb.CatalogLive.Explorer do
  use OnesqlxWeb, :live_view

  alias Onesqlx.Catalog
  alias Onesqlx.Catalog.SyncWorker
  alias Onesqlx.DataSources

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} wide>
      <.header>
        <.link navigate={~p"/data-sources"} class="text-base-content/60 hover:text-base-content">
          Data Sources
        </.link>
        <span class="text-base-content/40 mx-2">/</span>
        {@data_source.name} — Catalog Explorer
        <:actions>
          <.button phx-click="sync" variant="primary" disabled={@syncing?}>
            <span :if={@syncing?}>Syncing...</span>
            <span :if={!@syncing?}>Sync Catalog</span>
          </.button>
        </:actions>
      </.header>

      <div :if={!@synced? and !@syncing?} class="text-center py-12">
        <p class="text-base-content/60">
          No catalog data. Click "Sync Catalog" to import schema metadata.
        </p>
      </div>

      <div :if={@synced?} class="flex gap-6">
        <div class="w-64 shrink-0">
          <input
            type="text"
            placeholder="Filter..."
            phx-keyup="filter"
            value={@filter}
            class="input input-bordered input-sm w-full mb-3"
          />

          <ul class="menu menu-sm bg-base-200 rounded-box w-full">
            <li :for={schema <- filtered_schemas(@schemas, @filter)}>
              <button
                phx-click="select_schema"
                phx-value-id={schema.id}
                class={[@selected_schema && @selected_schema.id == schema.id && "active"]}
              >
                <.icon name="hero-circle-stack-micro" class="size-4" />
                {schema.name}
              </button>
              <ul :if={@selected_schema && @selected_schema.id == schema.id && @tables != []}>
                <li :for={table <- filtered_tables(@tables, @filter)}>
                  <button
                    phx-click="select_table"
                    phx-value-id={table.id}
                    class={[@selected_table && @selected_table.id == table.id && "active"]}
                  >
                    <.icon name={table_icon(table.table_type)} class="size-4" />
                    {table.name}
                  </button>
                </li>
              </ul>
            </li>
          </ul>
        </div>

        <div class="flex-1 min-w-0">
          <div :if={@selected_table && @columns != []}>
            <h3 class="text-lg font-semibold mb-3">
              {@selected_schema.name}.{@selected_table.name}
              <span class="badge badge-sm ml-2">{@selected_table.table_type}</span>
            </h3>

            <.table id="columns" rows={@columns} row_id={fn col -> col.id end}>
              <:col :let={col} label="#">{col.ordinal_position}</:col>
              <:col :let={col} label="Column">
                <span class="flex items-center gap-1">
                  <.icon
                    :if={col.is_primary_key}
                    name="hero-key-micro"
                    class="size-4 text-warning"
                  />
                  {col.name}
                </span>
              </:col>
              <:col :let={col} label="Type">{format_type(col)}</:col>
              <:col :let={col} label="Nullable">
                <span :if={col.is_nullable} class="text-success">YES</span>
                <span :if={!col.is_nullable} class="text-error">NO</span>
              </:col>
              <:col :let={col} label="Default">{col.column_default || "—"}</:col>
            </.table>
          </div>

          <div :if={!@selected_table} class="text-center py-12 text-base-content/60">
            <p>Select a table from the sidebar to view its columns.</p>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"data_source_id" => data_source_id}, _session, socket) do
    scope = socket.assigns.current_scope
    data_source = DataSources.get_data_source!(scope, data_source_id)
    schemas = Catalog.list_schemas(scope, data_source.id)

    socket =
      socket
      |> assign(:data_source, data_source)
      |> assign(:schemas, schemas)
      |> assign(:synced?, schemas != [])
      |> assign(:selected_schema, nil)
      |> assign(:tables, [])
      |> assign(:selected_table, nil)
      |> assign(:columns, [])
      |> assign(:filter, "")
      |> assign(:syncing?, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("select_schema", %{"id" => schema_id}, socket) do
    scope = socket.assigns.current_scope
    schema = Catalog.get_schema!(scope, schema_id)
    tables = Catalog.list_tables(scope, schema_id)

    socket =
      socket
      |> assign(:selected_schema, schema)
      |> assign(:tables, tables)
      |> assign(:selected_table, nil)
      |> assign(:columns, [])

    {:noreply, socket}
  end

  def handle_event("select_table", %{"id" => table_id}, socket) do
    scope = socket.assigns.current_scope
    table = Enum.find(socket.assigns.tables, &(&1.id == table_id))
    columns = Catalog.list_columns(scope, table_id)

    socket =
      socket
      |> assign(:selected_table, table)
      |> assign(:columns, columns)

    {:noreply, socket}
  end

  def handle_event("filter", %{"value" => value}, socket) do
    {:noreply, assign(socket, :filter, value)}
  end

  def handle_event("sync", _params, socket) do
    data_source = socket.assigns.data_source
    {:ok, _job} = SyncWorker.enqueue(data_source.id)

    socket =
      socket
      |> assign(:syncing?, true)
      |> put_flash(:info, "Catalog sync started. Refresh the page in a moment to see results.")

    {:noreply, socket}
  end

  defp filtered_schemas(schemas, ""), do: schemas

  defp filtered_schemas(schemas, filter) do
    filter = String.downcase(filter)
    Enum.filter(schemas, &String.contains?(String.downcase(&1.name), filter))
  end

  defp filtered_tables(tables, ""), do: tables

  defp filtered_tables(tables, filter) do
    filter = String.downcase(filter)
    Enum.filter(tables, &String.contains?(String.downcase(&1.name), filter))
  end

  defp table_icon("VIEW"), do: "hero-eye-micro"
  defp table_icon("MATERIALIZED VIEW"), do: "hero-eye-micro"
  defp table_icon(_), do: "hero-table-cells-micro"

  defp format_type(col) do
    case col.character_maximum_length do
      nil -> col.data_type
      len -> "#{col.data_type}(#{len})"
    end
  end
end
