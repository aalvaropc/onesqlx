defmodule OnesqlxWeb.LineageLive do
  @moduledoc """
  LiveView for data lineage visualization.

  Shows dependency trees: Dashboard → Queries → Tables, and reverse
  lookups from Table → Queries → Dashboards.
  """

  use OnesqlxWeb, :live_view

  alias Onesqlx.Dashboards
  alias Onesqlx.Lineage

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Data Lineage
        <:subtitle>Explore dependencies between dashboards, queries, and tables.</:subtitle>
      </.header>

      <div class="flex gap-4 mt-6 mb-6">
        <button
          phx-click="set_mode"
          phx-value-mode="dashboard"
          class={["btn btn-sm", @mode == :dashboard && "btn-primary"]}
        >
          Dashboard → Tables
        </button>
        <button
          phx-click="set_mode"
          phx-value-mode="table"
          class={["btn btn-sm", @mode == :table && "btn-primary"]}
        >
          Table → Dashboards
        </button>
      </div>

      <div :if={@mode == :dashboard}>
        <form phx-change="select_dashboard" class="max-w-sm mb-6">
          <select name="dashboard_id" class="select select-bordered w-full">
            <option value="">Select a dashboard...</option>
            <option
              :for={d <- @dashboards}
              value={d.id}
              selected={@selected_dashboard_id == d.id}
            >
              {d.title}
            </option>
          </select>
        </form>

        <div :if={@lineage}>
          <h2 class="text-lg font-semibold mb-4">{@lineage.dashboard.title}</h2>

          <div :if={@lineage.cards == []} class="text-base-content/50 text-sm">
            No cards in this dashboard.
          </div>

          <div class="space-y-4">
            <div
              :for={card <- @lineage.cards}
              class="border border-base-300 rounded-lg p-4"
            >
              <div class="flex items-center gap-2 mb-2">
                <.icon name="hero-squares-2x2" class="size-4 text-base-content/50" />
                <span class="font-medium">{card.title}</span>
              </div>

              <div :if={card.saved_query} class="ml-6 mb-2">
                <div class="flex items-center gap-2 text-sm">
                  <.icon name="hero-code-bracket" class="size-3.5 text-primary" />
                  <span>{card.saved_query.title}</span>
                </div>
              </div>

              <div :if={card.tables != []} class="ml-12 space-y-1">
                <div
                  :for={table <- card.tables}
                  class="flex items-center gap-2 text-sm text-base-content/70"
                >
                  <.icon name="hero-table-cells" class="size-3.5 text-secondary" />
                  <span class="font-mono text-xs">{table.schema}.{table.name}</span>
                </div>
              </div>

              <div
                :if={card.tables == [] && card.saved_query}
                class="ml-12 text-xs text-base-content/40"
              >
                No table references found
              </div>
            </div>
          </div>
        </div>
      </div>

      <div :if={@mode == :table}>
        <form phx-submit="search_table" class="max-w-sm mb-6">
          <div class="flex gap-2">
            <input
              type="text"
              name="table_name"
              value={@search_table}
              placeholder="Table name (e.g. orders)"
              class="input input-bordered flex-1"
            />
            <.button variant="primary">Search</.button>
          </div>
        </form>

        <div :if={@table_lineage}>
          <h2 class="text-lg font-semibold mb-4">
            Impact analysis for "{@search_table}"
          </h2>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <h3 class="font-medium mb-2">
                <.icon name="hero-code-bracket" class="size-4 inline" />
                Saved Queries ({length(@table_lineage.queries)})
              </h3>
              <div :if={@table_lineage.queries == []} class="text-sm text-base-content/50">
                No queries reference this table.
              </div>
              <div class="space-y-1">
                <div
                  :for={q <- @table_lineage.queries}
                  class="flex items-center gap-2 text-sm p-2 border border-base-300 rounded"
                >
                  <.icon name="hero-code-bracket" class="size-3.5 text-primary" />
                  {q.title}
                </div>
              </div>
            </div>

            <div>
              <h3 class="font-medium mb-2">
                <.icon name="hero-chart-bar-square" class="size-4 inline" />
                Dashboards ({length(@table_lineage.dashboards)})
              </h3>
              <div :if={@table_lineage.dashboards == []} class="text-sm text-base-content/50">
                No dashboards affected.
              </div>
              <div class="space-y-1">
                <.link
                  :for={d <- @table_lineage.dashboards}
                  navigate={~p"/dashboards/#{d.id}"}
                  class="flex items-center gap-2 text-sm p-2 border border-base-300 rounded hover:bg-base-200"
                >
                  <.icon name="hero-chart-bar-square" class="size-3.5 text-secondary" />
                  {d.title}
                </.link>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    dashboards = Dashboards.list_dashboards(scope)

    socket =
      assign(socket,
        dashboards: dashboards,
        mode: :dashboard,
        selected_dashboard_id: nil,
        lineage: nil,
        search_table: "",
        table_lineage: nil
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("set_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, mode: String.to_existing_atom(mode))}
  end

  def handle_event("select_dashboard", %{"dashboard_id" => ""}, socket) do
    {:noreply, assign(socket, selected_dashboard_id: nil, lineage: nil)}
  end

  def handle_event("select_dashboard", %{"dashboard_id" => id}, socket) do
    scope = socket.assigns.current_scope
    lineage = Lineage.build_dashboard_lineage(scope, id)
    {:noreply, assign(socket, selected_dashboard_id: id, lineage: lineage)}
  end

  def handle_event("search_table", %{"table_name" => name}, socket) do
    name = String.trim(name)

    if name == "" do
      {:noreply, assign(socket, table_lineage: nil, search_table: "")}
    else
      scope = socket.assigns.current_scope
      table_lineage = Lineage.build_table_lineage(scope, name)
      {:noreply, assign(socket, table_lineage: table_lineage, search_table: name)}
    end
  end
end
