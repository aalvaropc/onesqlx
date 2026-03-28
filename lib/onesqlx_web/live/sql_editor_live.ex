defmodule OnesqlxWeb.SqlEditorLive do
  @moduledoc """
  LiveView for the SQL Editor — write and execute read-only SQL against connected
  PostgreSQL data sources with CodeMirror 6, result display, and query history.
  """

  use OnesqlxWeb, :live_view

  alias Onesqlx.Catalog
  alias Onesqlx.DataSources
  alias Onesqlx.Querying
  alias Onesqlx.Querying.Params
  alias Onesqlx.SavedQueries
  alias Onesqlx.SavedQueries.SavedQuery

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} wide>
      <div class="flex flex-col h-[calc(100vh-10rem)]">
        <%!-- Toolbar --%>
        <div class="flex items-center gap-4 mb-4">
          <form phx-change="select_data_source" class="flex-1 max-w-xs">
            <select
              name="data_source_id"
              class="select select-bordered w-full"
            >
              <option value="">Select a data source...</option>
              <option
                :for={ds <- @data_sources}
                value={ds.id}
                selected={ds.id == @selected_data_source_id}
              >
                {ds.name}
              </option>
            </select>
          </form>

          <button
            phx-click="execute"
            disabled={@running? || @selected_data_source_id == nil}
            class={[
              "btn btn-primary btn-sm",
              (@running? || @selected_data_source_id == nil) && "btn-disabled"
            ]}
          >
            <span :if={@running?} class="loading loading-spinner loading-xs"></span>
            {if @running?, do: "Running...", else: "Run"}
          </button>

          <button
            phx-click="open_save_modal"
            disabled={@selected_data_source_id == nil || @sql == ""}
            class={[
              "btn btn-sm",
              (@selected_data_source_id == nil || @sql == "") && "btn-disabled"
            ]}
          >
            Save
          </button>

          <form
            :if={@result && @selected_data_source_id}
            action={~p"/exports/csv"}
            method="post"
            class="inline"
          >
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
            <input type="hidden" name="data_source_id" value={@selected_data_source_id} />
            <input type="hidden" name="sql" value={@sql} />
            <input type="hidden" name="label" value="sql_editor" />
            <button type="submit" class="btn btn-sm">
              <.icon name="hero-arrow-down-tray" class="size-4" /> CSV
            </button>
          </form>

          <span class="text-xs text-base-content/50">Ctrl+Enter to run</span>
        </div>

        <%!-- Editor + History side panel --%>
        <div class="flex gap-4 flex-1 min-h-0">
          <%!-- Editor column --%>
          <div class="flex flex-col flex-1 min-w-0">
            <%!-- CodeMirror Editor --%>
            <div
              id="sql-editor"
              phx-hook="SqlEditor"
              phx-update="ignore"
              class="border border-base-300 rounded-lg overflow-hidden h-48 flex-shrink-0"
            >
            </div>

            <%!-- Parameter input form --%>
            <div :if={@show_params_form?} class="border border-base-300 rounded-lg p-4 mt-2">
              <div class="flex items-center justify-between mb-2">
                <h4 class="text-sm font-semibold">Query Parameters</h4>
                <button phx-click="close_params_form" class="btn btn-xs btn-ghost">
                  <.icon name="hero-x-mark" class="size-3" />
                </button>
              </div>
              <div :for={param <- @query_params} class="flex items-center gap-2 mb-2">
                <label class="text-sm font-mono w-32">:{param}</label>
                <input
                  type="text"
                  phx-blur="update_param"
                  phx-value-name={param}
                  name={"params[#{param}]"}
                  value={Map.get(@param_values, param, "")}
                  phx-debounce="300"
                  class="input input-bordered input-sm flex-1"
                />
              </div>
              <button phx-click="execute_with_params" class="btn btn-primary btn-sm mt-2">
                Run with Parameters
              </button>
            </div>

            <%!-- Results area --%>
            <div class="flex flex-col flex-1 mt-4 min-h-0">
              <%!-- Tabs --%>
              <div class="tabs tabs-bordered">
                <button
                  phx-click="set_tab"
                  phx-value-tab="results"
                  class={["tab", @active_tab == :results && "tab-active"]}
                >
                  Results
                  <span
                    :if={@result}
                    class="badge badge-sm ml-1"
                  >
                    {@result.row_count}
                  </span>
                </button>
                <button
                  phx-click="set_tab"
                  phx-value-tab="messages"
                  class={["tab", @active_tab == :messages && "tab-active"]}
                >
                  Messages
                </button>
              </div>

              <%!-- Tab content --%>
              <div class="flex-1 overflow-auto mt-2">
                <div :if={@active_tab == :results}>
                  <div :if={@result} class="overflow-x-auto">
                    <table class="table table-xs table-pin-rows">
                      <thead>
                        <tr>
                          <th :for={col <- @result.columns} class="bg-base-200">
                            {col}
                          </th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr :for={row <- @result.rows}>
                          <td :for={cell <- row} class="font-mono text-xs">
                            {format_cell(cell)}
                          </td>
                        </tr>
                      </tbody>
                    </table>
                    <p
                      :if={length(@result.rows) < @result.row_count}
                      class="text-xs text-base-content/50 mt-2"
                    >
                      Showing {length(@result.rows)} of {@result.row_count} rows
                    </p>
                    <p class="text-xs text-base-content/50 mt-1">
                      Completed in {@result.duration_ms}ms
                    </p>
                  </div>
                  <p :if={!@result && !@error} class="text-base-content/50 text-sm py-4">
                    Run a query to see results.
                  </p>
                </div>

                <div :if={@active_tab == :messages}>
                  <div :if={@error} class="alert alert-error text-sm">
                    {@error}
                  </div>
                  <p :if={!@error && @result} class="text-success text-sm py-4">
                    Query executed successfully.
                  </p>
                  <p :if={!@error && !@result} class="text-base-content/50 text-sm py-4">
                    No messages.
                  </p>
                </div>
              </div>
            </div>
          </div>

          <%!-- History side panel --%>
          <div class="w-72 flex-shrink-0 flex flex-col min-h-0 border-l border-base-300 pl-4">
            <h3 class="text-sm font-semibold mb-2">Recent Queries</h3>
            <div class="flex-1 overflow-y-auto space-y-2">
              <div
                :for={{dom_id, run} <- @streams.history}
                id={dom_id}
                phx-click="reopen_query"
                phx-value-id={run.id}
                class="p-2 border border-base-300 rounded cursor-pointer hover:bg-base-200 transition-colors"
              >
                <div class="flex items-center gap-2 mb-1">
                  <span class={[
                    "badge badge-xs",
                    run.status == "success" && "badge-success",
                    run.status == "error" && "badge-error",
                    run.status == "timeout" && "badge-warning",
                    run.status == "blocked" && "badge-error"
                  ]}>
                    {run.status}
                  </span>
                  <span :if={run.duration_ms} class="text-xs text-base-content/50">
                    {run.duration_ms}ms
                  </span>
                </div>
                <p class="text-xs font-mono truncate">{run.sql}</p>
              </div>
              <p
                :if={@selected_data_source_id == nil}
                class="text-xs text-base-content/50"
              >
                Select a data source to view history.
              </p>
            </div>
          </div>
        </div>
      </div>
      <%!-- Save Query Modal --%>
      <div :if={@show_save_modal?} class="fixed inset-0 z-50 flex items-center justify-center">
        <div class="fixed inset-0 bg-black/50" phx-click="close_save_modal"></div>
        <div class="relative bg-base-100 rounded-lg p-6 w-full max-w-md shadow-xl">
          <h3 class="text-lg font-semibold mb-4">Save Query</h3>
          <.form
            for={@save_form}
            id="save-query-form"
            phx-submit="save_query"
            phx-change="validate_save"
          >
            <.input field={@save_form[:title]} type="text" label="Title" required />
            <.input field={@save_form[:description]} type="textarea" label="Description (optional)" />
            <div class="flex justify-end gap-2 mt-4">
              <button type="button" phx-click="close_save_modal" class="btn btn-sm">
                Cancel
              </button>
              <.button variant="primary" phx-disable-with="Saving...">Save</.button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    data_sources = DataSources.list_data_sources(scope)

    socket =
      socket
      |> assign(
        data_sources: data_sources,
        selected_data_source_id: nil,
        sql: "",
        running?: false,
        result: nil,
        error: nil,
        active_tab: :results,
        show_save_modal?: false,
        save_form: nil,
        query_params: [],
        param_values: %{},
        show_params_form?: false
      )
      |> stream(:history, [])

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"saved_query_id" => id}, _uri, socket) do
    {:noreply, load_saved_query(socket, id)}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("select_data_source", %{"data_source_id" => ""}, socket) do
    socket =
      socket
      |> assign(selected_data_source_id: nil, result: nil, error: nil)
      |> stream(:history, [], reset: true)

    {:noreply, socket}
  end

  def handle_event("select_data_source", %{"data_source_id" => ds_id}, socket) do
    scope = socket.assigns.current_scope
    runs = Querying.list_recent_runs(scope, ds_id)

    schema_map =
      case Catalog.autocomplete_schema(scope, ds_id) do
        map when is_map(map) -> map
        _ -> %{}
      end

    socket =
      socket
      |> assign(selected_data_source_id: ds_id, result: nil, error: nil)
      |> stream(:history, runs, reset: true)
      |> push_event("set_catalog", %{schema: schema_map})

    {:noreply, socket}
  end

  def handle_event("update_sql", %{"sql" => sql}, socket) do
    {:noreply, assign(socket, sql: sql)}
  end

  def handle_event("execute", _params, socket) do
    ds_id = socket.assigns.selected_data_source_id
    sql = socket.assigns.sql

    if ds_id == nil || String.trim(sql) == "" do
      {:noreply, socket}
    else
      detected_params = Params.extract(sql)

      if detected_params != [] && !socket.assigns.show_params_form? do
        {:noreply,
         assign(socket, query_params: detected_params, show_params_form?: true, param_values: %{})}
      else
        execute_sql(socket)
      end
    end
  end

  def handle_event("update_param", %{"name" => name, "value" => value}, socket) do
    param_values = Map.put(socket.assigns.param_values, name, value)
    {:noreply, assign(socket, param_values: param_values)}
  end

  def handle_event("execute_with_params", _params, socket) do
    {:noreply, execute_sql(socket) |> elem(1)}
  end

  def handle_event("close_params_form", _params, socket) do
    {:noreply, assign(socket, show_params_form?: false, query_params: [], param_values: %{})}
  end

  def handle_event("set_tab", %{"tab" => tab}, socket) do
    tab = String.to_existing_atom(tab)
    {:noreply, assign(socket, active_tab: tab)}
  end

  def handle_event("reopen_query", %{"id" => run_id}, socket) do
    scope = socket.assigns.current_scope
    run = Querying.get_query_run!(scope, run_id)

    socket =
      socket
      |> assign(sql: run.sql)
      |> push_event("set_sql", %{sql: run.sql})

    socket =
      if run.data_source_id && run.data_source_id != socket.assigns.selected_data_source_id do
        assign(socket, selected_data_source_id: run.data_source_id)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("open_save_modal", _params, socket) do
    changeset = SavedQueries.change_saved_query(%SavedQuery{})
    form = to_form(changeset, as: "saved_query")
    {:noreply, assign(socket, show_save_modal?: true, save_form: form)}
  end

  def handle_event("close_save_modal", _params, socket) do
    {:noreply, assign(socket, show_save_modal?: false, save_form: nil)}
  end

  def handle_event("validate_save", %{"saved_query" => params}, socket) do
    changeset =
      %SavedQuery{}
      |> SavedQueries.change_saved_query(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, save_form: to_form(changeset, as: "saved_query"))}
  end

  def handle_event("save_query", %{"saved_query" => params}, socket) do
    scope = socket.assigns.current_scope

    attrs =
      Map.merge(params, %{
        "sql" => socket.assigns.sql,
        "data_source_id" => socket.assigns.selected_data_source_id,
        "user_id" => scope.user.id
      })

    case SavedQueries.create_saved_query(scope, attrs) do
      {:ok, _saved_query} ->
        {:noreply,
         socket
         |> assign(show_save_modal?: false, save_form: nil)
         |> put_flash(:info, "Query saved successfully.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, save_form: to_form(changeset, as: "saved_query"))}
    end
  end

  @impl true
  def handle_async(:execute_query, {:ok, {:ok, result}}, socket) do
    socket =
      socket
      |> assign(running?: false, result: result, error: nil, active_tab: :results)
      |> refresh_history()

    {:noreply, socket}
  end

  def handle_async(:execute_query, {:ok, {:error, _type, message}}, socket) do
    socket =
      socket
      |> assign(running?: false, result: nil, error: message, active_tab: :messages)
      |> refresh_history()

    {:noreply, socket}
  end

  def handle_async(:execute_query, {:exit, reason}, socket) do
    socket =
      socket
      |> assign(running?: false, result: nil, error: "Query process crashed: #{inspect(reason)}")
      |> refresh_history()

    {:noreply, socket}
  end

  defp load_saved_query(socket, saved_query_id) do
    scope = socket.assigns.current_scope
    saved_query = SavedQueries.get_saved_query!(scope, saved_query_id)

    socket =
      socket
      |> assign(sql: saved_query.sql)
      |> push_event("set_sql", %{sql: saved_query.sql})

    if saved_query.data_source_id do
      ds_id = saved_query.data_source_id
      runs = Querying.list_recent_runs(scope, ds_id)

      schema_map =
        case Catalog.autocomplete_schema(scope, ds_id) do
          map when is_map(map) -> map
          _ -> %{}
        end

      socket
      |> assign(selected_data_source_id: ds_id, result: nil, error: nil)
      |> stream(:history, runs, reset: true)
      |> push_event("set_catalog", %{schema: schema_map})
    else
      socket
    end
  end

  defp execute_sql(socket) do
    scope = socket.assigns.current_scope
    ds_id = socket.assigns.selected_data_source_id
    sql = socket.assigns.sql
    params = socket.assigns.param_values
    data_source = DataSources.get_data_source!(scope, ds_id)

    socket =
      socket
      |> assign(running?: true, result: nil, error: nil, show_params_form?: false)
      |> start_async(:execute_query, fn ->
        Querying.execute_query(scope, data_source, sql, params)
      end)

    {:noreply, socket}
  end

  defp refresh_history(socket) do
    case socket.assigns.selected_data_source_id do
      nil ->
        socket

      ds_id ->
        scope = socket.assigns.current_scope
        runs = Querying.list_recent_runs(scope, ds_id)
        stream(socket, :history, runs, reset: true)
    end
  end

  defp format_cell(nil), do: "NULL"
  defp format_cell(true), do: "true"
  defp format_cell(false), do: "false"

  defp format_cell(value) when is_binary(value) do
    if String.length(value) > 500 do
      String.slice(value, 0, 500) <> "..."
    else
      value
    end
  end

  defp format_cell(value), do: inspect(value)
end
