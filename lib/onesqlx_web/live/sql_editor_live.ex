defmodule OnesqlxWeb.SqlEditorLive do
  @moduledoc """
  LiveView for the SQL Editor with multi-tab support.

  Each tab maintains its own SQL, data source, results, and execution state.
  A single CodeMirror instance swaps content on tab switch.
  """

  use OnesqlxWeb, :live_view

  @query_timeout_ms 60_000
  @timeout_message "Query timed out after 60 seconds. The database may still be processing the query."

  alias Onesqlx.Catalog
  alias Onesqlx.DataSources
  alias Onesqlx.Querying
  alias Onesqlx.Querying.Executor
  alias Onesqlx.Querying.Params
  alias Onesqlx.Querying.SqlFormatter
  alias Onesqlx.SavedQueries
  alias Onesqlx.SavedQueries.SavedQuery

  # -- Render ------------------------------------------------------------------

  @impl true
  def render(assigns) do
    tab = assigns.tabs[assigns.active_tab_id]
    assigns = assign(assigns, :tab, tab)

    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} wide>
      <div class="flex flex-col h-[calc(100vh-10rem)]">
        <%!-- Tab bar --%>
        <div class="flex items-center gap-1 mb-2 border-b border-base-300 overflow-x-auto">
          <div
            :for={tab_id <- @tab_order}
            class={[
              "flex items-center gap-1 px-3 py-1.5 text-sm cursor-pointer border-b-2 whitespace-nowrap flex-shrink-0",
              tab_id == @active_tab_id && "border-primary font-semibold",
              tab_id != @active_tab_id && "border-transparent hover:bg-base-200"
            ]}
          >
            <span phx-click="switch_tab" phx-value-id={tab_id}>
              {@tabs[tab_id].name}
              <span
                :if={@tabs[tab_id].running?}
                class="loading loading-spinner loading-xs ml-1"
              >
              </span>
            </span>
            <button
              :if={length(@tab_order) > 1}
              phx-click="close_tab"
              phx-value-id={tab_id}
              class="btn btn-ghost btn-xs px-0.5 ml-1"
              aria-label="Close tab"
            >
              <.icon name="hero-x-mark" class="size-3" />
            </button>
          </div>
          <button
            phx-click="new_tab"
            class="btn btn-ghost btn-xs px-2 flex-shrink-0"
            aria-label="New tab"
          >
            <.icon name="hero-plus" class="size-3" />
          </button>
        </div>

        <%!-- Toolbar --%>
        <div class="flex items-center gap-4 mb-4">
          <form id="ds-selector" phx-change="select_data_source" class="flex-1 max-w-xs">
            <select
              name="data_source_id"
              class="select select-bordered w-full"
            >
              <option value="">Select a data source...</option>
              <option
                :for={ds <- @data_sources}
                value={ds.id}
                selected={ds.id == @tab.data_source_id}
              >
                {ds.name}
              </option>
            </select>
          </form>

          <button
            :if={!@tab.running?}
            phx-click="execute"
            disabled={@tab.data_source_id == nil}
            class={[
              "btn btn-primary btn-sm",
              @tab.data_source_id == nil && "btn-disabled"
            ]}
          >
            Run
          </button>
          <button :if={@tab.running?} phx-click="cancel_query" class="btn btn-error btn-sm">
            <span class="loading loading-spinner loading-xs"></span> Cancel
          </button>

          <button
            phx-click="explain"
            disabled={@tab.running? || @tab.data_source_id == nil}
            class={[
              "btn btn-sm",
              (@tab.running? || @tab.data_source_id == nil) && "btn-disabled"
            ]}
          >
            Explain
          </button>

          <button
            phx-click="open_save_modal"
            disabled={@tab.data_source_id == nil || @tab.sql == ""}
            class={[
              "btn btn-sm",
              (@tab.data_source_id == nil || @tab.sql == "") && "btn-disabled"
            ]}
          >
            Save
          </button>

          <button
            phx-click="format_sql"
            disabled={@tab.sql == ""}
            class={["btn btn-sm", @tab.sql == "" && "btn-disabled"]}
          >
            Format
          </button>

          <form
            :if={@tab.result && @tab.data_source_id}
            action={~p"/exports/csv"}
            method="post"
            class="inline"
          >
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
            <input type="hidden" name="data_source_id" value={@tab.data_source_id} />
            <input type="hidden" name="sql" value={@tab.sql} />
            <input type="hidden" name="label" value="sql_editor" />
            <button type="submit" class="btn btn-sm">
              <.icon name="hero-arrow-down-tray" class="size-4" /> CSV
            </button>
          </form>

          <form phx-change="set_row_limit" class="inline">
            <select name="row_limit" class="select select-bordered select-sm w-28">
              <option value="100" selected={@tab.row_limit == 100}>100 rows</option>
              <option value="500" selected={@tab.row_limit == 500}>500 rows</option>
              <option value="1000" selected={@tab.row_limit == 1000}>1,000 rows</option>
              <option value="5000" selected={@tab.row_limit == 5000}>5,000 rows</option>
              <option value="10000" selected={@tab.row_limit == 10000}>10,000 rows</option>
            </select>
          </form>

          <span class="text-xs text-base-content/50">Ctrl+Enter to run</span>
        </div>

        <%!-- Editor + History side panel --%>
        <div class="flex flex-col lg:flex-row gap-4 flex-1 min-h-0">
          <%!-- Editor column --%>
          <div class="flex flex-col flex-1 min-w-0">
            <%!-- CodeMirror Editor --%>
            <div
              id="sql-editor"
              phx-hook="SqlEditor"
              phx-update="ignore"
              class="border border-base-300 rounded-lg overflow-hidden h-32 md:h-48 flex-shrink-0"
            >
            </div>

            <%!-- Parameter input form --%>
            <div :if={@tab.show_params_form?} class="border border-base-300 rounded-lg p-4 mt-2">
              <div class="flex items-center justify-between mb-2">
                <h4 class="text-sm font-semibold">Query Parameters</h4>
                <button phx-click="close_params_form" aria-label="Close" class="btn btn-xs btn-ghost">
                  <.icon name="hero-x-mark" class="size-3" />
                </button>
              </div>
              <div :for={param <- @tab.query_params} class="flex items-center gap-2 mb-2">
                <label class="text-sm font-mono w-32">:{param}</label>
                <input
                  type={Params.infer_input_type(param)}
                  phx-blur="update_param"
                  phx-value-name={param}
                  name={"params[#{param}]"}
                  value={Map.get(@tab.param_values, param, "")}
                  phx-debounce="300"
                  step={if Params.infer_input_type(param) == "number", do: "any"}
                  class="input input-bordered input-sm flex-1"
                />
              </div>
              <button phx-click="execute_with_params" class="btn btn-primary btn-sm mt-2">
                Run with Parameters
              </button>
            </div>

            <%!-- Results area --%>
            <div class="flex flex-col flex-1 mt-4 min-h-0">
              <%!-- Result tabs --%>
              <div class="tabs tabs-bordered">
                <button
                  phx-click="set_result_tab"
                  phx-value-tab="results"
                  class={["tab", @tab.active_result_tab == :results && "tab-active"]}
                >
                  Results
                  <span :if={@tab.result} class="badge badge-sm ml-1">
                    {@tab.result.row_count}
                  </span>
                </button>
                <button
                  phx-click="set_result_tab"
                  phx-value-tab="messages"
                  class={["tab", @tab.active_result_tab == :messages && "tab-active"]}
                >
                  Messages
                </button>
                <button
                  phx-click="set_result_tab"
                  phx-value-tab="explain"
                  class={["tab", @tab.active_result_tab == :explain && "tab-active"]}
                >
                  Explain
                </button>
              </div>

              <%!-- Tab content --%>
              <div class="flex-1 overflow-auto mt-2">
                <div :if={@tab.active_result_tab == :results}>
                  <div
                    :if={@tab.result}
                    id="result-table"
                    phx-hook="CopyTable"
                    class="overflow-x-auto"
                  >
                    <table class="table table-xs table-pin-rows">
                      <thead>
                        <tr>
                          <th
                            :for={{col, idx} <- Enum.with_index(@tab.result.columns)}
                            class="bg-base-200 cursor-pointer select-none hover:bg-base-300"
                            phx-click="sort_results"
                            phx-value-column={idx}
                          >
                            <span class="flex items-center gap-1">
                              {col}
                              <span :if={@tab.sort_column == idx} class="text-xs">
                                {if @tab.sort_direction == :asc, do: "↑", else: "↓"}
                              </span>
                            </span>
                          </th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr :for={
                          row <- sort_rows(@tab.result.rows, @tab.sort_column, @tab.sort_direction)
                        }>
                          <td
                            :for={cell <- row}
                            data-copy={format_cell(cell)}
                            class="font-mono text-xs cursor-pointer hover:bg-base-200"
                            title="Click to copy"
                          >
                            {format_cell(cell)}
                            <button
                              :if={truncated?(cell)}
                              phx-click="view_cell"
                              phx-value-text={raw_cell(cell)}
                              class="btn btn-ghost btn-xs px-0.5 ml-1 opacity-40 hover:opacity-100"
                              title="View full text"
                            >
                              <.icon name="hero-arrows-pointing-out" class="size-3" />
                            </button>
                          </td>
                          <td class="px-1">
                            <button
                              data-copy-row
                              class="btn btn-ghost btn-xs px-0.5 opacity-30 hover:opacity-100"
                              title="Copy row"
                            >
                              <.icon name="hero-clipboard" class="size-3" />
                            </button>
                          </td>
                        </tr>
                      </tbody>
                    </table>
                    <p
                      :if={length(@tab.result.rows) < @tab.result.row_count}
                      class="text-xs text-base-content/50 mt-2"
                    >
                      Showing {length(@tab.result.rows)} of {@tab.result.row_count} rows
                    </p>
                    <p class="text-xs text-base-content/50 mt-1">
                      Completed in {@tab.result.duration_ms}ms
                    </p>
                  </div>
                  <p :if={!@tab.result && !@tab.error} class="text-base-content/50 text-sm py-4">
                    Run a query to see results.
                  </p>
                </div>

                <div :if={@tab.active_result_tab == :messages}>
                  <div :if={@tab.error} class="alert alert-error text-sm">
                    {@tab.error}
                  </div>
                  <p :if={!@tab.error && @tab.result} class="text-success text-sm py-4">
                    Query executed successfully.
                  </p>
                  <p :if={!@tab.error && !@tab.result} class="text-base-content/50 text-sm py-4">
                    No messages.
                  </p>
                </div>

                <div :if={@tab.active_result_tab == :explain}>
                  <pre
                    :if={@tab.explain_plan}
                    class="text-xs font-mono whitespace-pre overflow-x-auto bg-base-200 rounded p-4"
                  >{@tab.explain_plan}</pre>
                  <div :if={@tab.explain_error} class="alert alert-error text-sm">
                    {@tab.explain_error}
                  </div>
                  <p
                    :if={!@tab.explain_plan && !@tab.explain_error}
                    class="text-base-content/50 text-sm py-4"
                  >
                    Click "Explain" to see the query execution plan.
                  </p>
                </div>
              </div>
            </div>
          </div>

          <%!-- History side panel --%>
          <div class="hidden lg:flex w-72 flex-shrink-0 flex-col min-h-0 border-l border-base-300 pl-4">
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
                :if={@tab.data_source_id == nil}
                class="text-xs text-base-content/50"
              >
                Select a data source to view history.
              </p>
            </div>
          </div>
        </div>
      </div>
      <%!-- Save Query Modal --%>
      <div
        :if={@show_save_modal?}
        role="dialog"
        aria-modal="true"
        class="fixed inset-0 z-50 flex items-center justify-center"
      >
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

      <div
        :if={@viewing_cell}
        role="dialog"
        aria-modal="true"
        class="fixed inset-0 z-50 flex items-center justify-center"
      >
        <div class="fixed inset-0 bg-black/50" phx-click="close_cell_view"></div>
        <div class="relative bg-base-100 rounded-lg p-6 w-full max-w-2xl max-h-[70vh] shadow-xl flex flex-col">
          <div class="flex items-center justify-between mb-3">
            <h3 class="text-sm font-semibold">Cell Content</h3>
            <button phx-click="close_cell_view" class="btn btn-sm btn-ghost">
              <.icon name="hero-x-mark" class="size-4" />
            </button>
          </div>
          <pre class="flex-1 overflow-auto bg-base-200 rounded p-4 text-xs font-mono whitespace-pre-wrap break-all">{@viewing_cell}</pre>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # -- Mount -------------------------------------------------------------------

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    data_sources = DataSources.list_data_sources(scope)
    tab = new_tab("Tab 1")

    socket =
      socket
      |> assign(
        data_sources: data_sources,
        tabs: %{tab.id => tab},
        active_tab_id: tab.id,
        tab_order: [tab.id],
        tab_counter: 1,
        show_save_modal?: false,
        save_form: nil,
        viewing_cell: nil
      )
      |> stream(:history, [])

    {:ok, socket}
  end

  # -- Handle Params -----------------------------------------------------------

  @impl true
  def handle_params(%{"saved_query_id" => id}, _uri, socket) do
    {:noreply, load_saved_query(socket, id)}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  # -- Tab Management Events ---------------------------------------------------

  @impl true
  def handle_event("new_tab", _params, socket) do
    counter = socket.assigns.tab_counter + 1
    tab = new_tab("Tab #{counter}")

    socket =
      socket
      |> update(:tabs, &Map.put(&1, tab.id, tab))
      |> update(:tab_order, &(&1 ++ [tab.id]))
      |> assign(active_tab_id: tab.id, tab_counter: counter)
      |> push_event("set_sql", %{sql: ""})
      |> stream(:history, [], reset: true)

    {:noreply, socket}
  end

  def handle_event("close_tab", %{"id" => tab_id}, socket) do
    if length(socket.assigns.tab_order) <= 1 do
      {:noreply, socket}
    else
      closing_tab = socket.assigns.tabs[tab_id]
      cancel_timeout(closing_tab.timeout_ref)

      new_order = Enum.reject(socket.assigns.tab_order, &(&1 == tab_id))
      new_tabs = Map.delete(socket.assigns.tabs, tab_id)

      new_active =
        if socket.assigns.active_tab_id == tab_id do
          idx = Enum.find_index(socket.assigns.tab_order, &(&1 == tab_id))
          Enum.at(new_order, min(idx, length(new_order) - 1))
        else
          socket.assigns.active_tab_id
        end

      socket =
        socket
        |> assign(tabs: new_tabs, tab_order: new_order, active_tab_id: new_active)
        |> sync_editor_to_active_tab()

      {:noreply, socket}
    end
  end

  def handle_event("switch_tab", %{"id" => tab_id}, socket) do
    if tab_id == socket.assigns.active_tab_id do
      {:noreply, socket}
    else
      socket =
        socket
        |> assign(active_tab_id: tab_id)
        |> sync_editor_to_active_tab()

      {:noreply, socket}
    end
  end

  # -- Data Source Selection ---------------------------------------------------

  def handle_event("select_data_source", %{"data_source_id" => ""}, socket) do
    tab = get_active_tab(socket)
    updated = %{tab | data_source_id: nil, result: nil, error: nil}

    socket =
      socket
      |> put_tab(updated)
      |> stream(:history, [], reset: true)

    {:noreply, socket}
  end

  def handle_event("select_data_source", %{"data_source_id" => ds_id}, socket) do
    scope = socket.assigns.current_scope
    runs = Querying.list_recent_runs(scope, ds_id)
    schema_map = load_schema_map(scope, ds_id)

    tab = get_active_tab(socket)
    updated = %{tab | data_source_id: ds_id, result: nil, error: nil}

    socket =
      socket
      |> put_tab(updated)
      |> stream(:history, runs, reset: true)
      |> push_event("set_catalog", %{schema: schema_map})

    {:noreply, socket}
  end

  # -- SQL Update --------------------------------------------------------------

  def handle_event("update_sql", %{"sql" => sql}, socket) do
    tab = get_active_tab(socket)
    {:noreply, put_tab(socket, %{tab | sql: sql})}
  end

  # -- Execute -----------------------------------------------------------------

  def handle_event("execute", params, socket) do
    tab = get_active_tab(socket)
    sql = Map.get(params, "sql", tab.sql)

    if tab.data_source_id == nil || String.trim(sql) == "" do
      {:noreply, socket}
    else
      updated = %{tab | execute_sql: sql}
      socket = put_tab(socket, updated)
      detected_params = Params.extract(sql)

      if detected_params != [] && !tab.show_params_form? do
        updated2 = %{
          updated
          | query_params: detected_params,
            show_params_form?: true,
            param_values: %{}
        }

        {:noreply, put_tab(socket, updated2)}
      else
        execute_sql(socket)
      end
    end
  end

  def handle_event("update_param", %{"name" => name, "value" => value}, socket) do
    tab = get_active_tab(socket)
    updated = %{tab | param_values: Map.put(tab.param_values, name, value)}
    {:noreply, put_tab(socket, updated)}
  end

  def handle_event("execute_with_params", _params, socket) do
    {:noreply, execute_sql(socket) |> elem(1)}
  end

  def handle_event("close_params_form", _params, socket) do
    tab = get_active_tab(socket)
    updated = %{tab | show_params_form?: false, query_params: [], param_values: %{}}
    {:noreply, put_tab(socket, updated)}
  end

  def handle_event("format_sql", _params, socket) do
    tab = get_active_tab(socket)
    formatted = SqlFormatter.format(tab.sql)
    updated = %{tab | sql: formatted}

    socket =
      socket
      |> put_tab(updated)
      |> push_event("set_sql", %{sql: formatted})

    {:noreply, socket}
  end

  # -- Cancel ------------------------------------------------------------------

  def handle_event("cancel_query", _params, socket) do
    tab = get_active_tab(socket)

    if tab.running? && tab.cancel_ref && tab.data_source_id do
      scope = socket.assigns.current_scope
      data_source = DataSources.get_data_source!(scope, tab.data_source_id)
      cancel_ref = tab.cancel_ref

      Task.start(fn -> Executor.cancel_query(data_source, cancel_ref) end)

      cancel_timeout(tab.timeout_ref)

      updated = %{
        tab
        | running?: false,
          error: "Query cancelled.",
          active_result_tab: :messages,
          timeout_ref: nil,
          cancel_ref: nil
      }

      {:noreply, put_tab(socket, updated)}
    else
      {:noreply, socket}
    end
  end

  # -- Explain -----------------------------------------------------------------

  def handle_event("explain", _params, socket) do
    tab = get_active_tab(socket)

    if tab.data_source_id == nil || String.trim(tab.sql) == "" do
      {:noreply, socket}
    else
      scope = socket.assigns.current_scope
      data_source = DataSources.get_data_source!(scope, tab.data_source_id)
      tab_id = tab.id

      updated = %{
        tab
        | running?: true,
          explain_plan: nil,
          explain_error: nil,
          active_result_tab: :explain
      }

      socket =
        socket
        |> put_tab(updated)
        |> start_async({:explain_query, tab_id}, fn ->
          Executor.explain(data_source, tab.sql)
        end)

      {:noreply, socket}
    end
  end

  # -- Result Tab Switch -------------------------------------------------------

  def handle_event("set_result_tab", %{"tab" => tab_name}, socket) do
    tab = get_active_tab(socket)
    updated = %{tab | active_result_tab: String.to_existing_atom(tab_name)}
    {:noreply, put_tab(socket, updated)}
  end

  def handle_event("sort_results", %{"column" => col_str}, socket) do
    tab = get_active_tab(socket)
    col_index = String.to_integer(col_str)

    direction =
      if tab.sort_column == col_index do
        if tab.sort_direction == :asc, do: :desc, else: :asc
      else
        :asc
      end

    updated = %{tab | sort_column: col_index, sort_direction: direction}
    {:noreply, put_tab(socket, updated)}
  end

  def handle_event("set_row_limit", %{"row_limit" => limit_str}, socket) do
    tab = get_active_tab(socket)
    updated = %{tab | row_limit: String.to_integer(limit_str)}
    {:noreply, put_tab(socket, updated)}
  end

  # -- History Reopen ----------------------------------------------------------

  def handle_event("reopen_query", %{"id" => run_id}, socket) do
    scope = socket.assigns.current_scope
    run = Querying.get_query_run!(scope, run_id)
    tab = get_active_tab(socket)

    updated =
      if run.data_source_id && run.data_source_id != tab.data_source_id do
        %{tab | sql: run.sql, data_source_id: run.data_source_id}
      else
        %{tab | sql: run.sql}
      end

    socket =
      socket
      |> put_tab(updated)
      |> push_event("set_sql", %{sql: run.sql})

    {:noreply, socket}
  end

  # -- Save Modal --------------------------------------------------------------

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
    tab = get_active_tab(socket)

    attrs =
      Map.merge(params, %{
        "sql" => tab.sql,
        "data_source_id" => tab.data_source_id,
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

  def handle_event("view_cell", %{"text" => text}, socket) do
    {:noreply, assign(socket, viewing_cell: text)}
  end

  def handle_event("close_cell_view", _params, socket) do
    {:noreply, assign(socket, viewing_cell: nil)}
  end

  # -- Handle Async ------------------------------------------------------------

  @impl true
  def handle_async({:execute_query, tab_id}, {:ok, {:ok, result}}, socket) do
    case socket.assigns.tabs[tab_id] do
      %{running?: true} = tab ->
        cancel_timeout(tab.timeout_ref)

        updated = %{
          tab
          | running?: false,
            result: result,
            error: nil,
            active_result_tab: :results,
            timeout_ref: nil
        }

        socket =
          socket
          |> put_tab(updated)
          |> maybe_refresh_history(tab_id)

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_async({:execute_query, tab_id}, {:ok, {:error, _type, message}}, socket) do
    case socket.assigns.tabs[tab_id] do
      %{running?: true} = tab ->
        cancel_timeout(tab.timeout_ref)

        updated = %{
          tab
          | running?: false,
            result: nil,
            error: message,
            active_result_tab: :messages,
            timeout_ref: nil
        }

        socket =
          socket
          |> put_tab(updated)
          |> maybe_refresh_history(tab_id)

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_async({:execute_query, tab_id}, {:exit, reason}, socket) do
    case socket.assigns.tabs[tab_id] do
      %{running?: true} = tab ->
        cancel_timeout(tab.timeout_ref)
        msg = "Query process crashed: #{inspect(reason)}"
        updated = %{tab | running?: false, result: nil, error: msg, timeout_ref: nil}

        socket =
          socket
          |> put_tab(updated)
          |> maybe_refresh_history(tab_id)

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_async({:explain_query, tab_id}, {:ok, {:ok, plan_text}}, socket) do
    case socket.assigns.tabs[tab_id] do
      nil ->
        {:noreply, socket}

      tab ->
        updated = %{tab | running?: false, explain_plan: plan_text, explain_error: nil}
        {:noreply, put_tab(socket, updated)}
    end
  end

  def handle_async({:explain_query, tab_id}, {:ok, {:error, _type, message}}, socket) do
    case socket.assigns.tabs[tab_id] do
      nil ->
        {:noreply, socket}

      tab ->
        updated = %{tab | running?: false, explain_plan: nil, explain_error: message}
        {:noreply, put_tab(socket, updated)}
    end
  end

  def handle_async({:explain_query, tab_id}, {:exit, reason}, socket) do
    case socket.assigns.tabs[tab_id] do
      nil ->
        {:noreply, socket}

      tab ->
        updated = %{
          tab
          | running?: false,
            explain_plan: nil,
            explain_error: "Explain crashed: #{inspect(reason)}"
        }

        {:noreply, put_tab(socket, updated)}
    end
  end

  # -- Handle Info (timeout) ---------------------------------------------------

  @impl true
  def handle_info({:query_timeout, tab_id}, socket) do
    case socket.assigns.tabs[tab_id] do
      %{running?: true} = tab ->
        updated = %{
          tab
          | running?: false,
            result: nil,
            error: @timeout_message,
            active_result_tab: :messages,
            timeout_ref: nil
        }

        {:noreply, put_tab(socket, updated)}

      _ ->
        {:noreply, socket}
    end
  end

  # -- Private Helpers ---------------------------------------------------------

  defp new_tab(name) do
    %{
      id: Ecto.UUID.generate(),
      name: name,
      sql: "",
      data_source_id: nil,
      result: nil,
      error: nil,
      running?: false,
      active_result_tab: :results,
      explain_plan: nil,
      explain_error: nil,
      param_values: %{},
      query_params: [],
      show_params_form?: false,
      execute_sql: "",
      timeout_ref: nil,
      cancel_ref: nil,
      sort_column: nil,
      sort_direction: :asc,
      row_limit: 1000
    }
  end

  defp get_active_tab(socket) do
    socket.assigns.tabs[socket.assigns.active_tab_id]
  end

  defp put_tab(socket, tab) do
    update(socket, :tabs, &Map.put(&1, tab.id, tab))
  end

  defp sync_editor_to_active_tab(socket) do
    tab = socket.assigns.tabs[socket.assigns.active_tab_id]

    socket = push_event(socket, "set_sql", %{sql: tab.sql})

    if tab.data_source_id do
      scope = socket.assigns.current_scope
      runs = Querying.list_recent_runs(scope, tab.data_source_id)
      schema_map = load_schema_map(scope, tab.data_source_id)

      socket
      |> stream(:history, runs, reset: true)
      |> push_event("set_catalog", %{schema: schema_map})
    else
      stream(socket, :history, [], reset: true)
    end
  end

  defp load_saved_query(socket, saved_query_id) do
    scope = socket.assigns.current_scope
    saved_query = SavedQueries.get_saved_query!(scope, saved_query_id)

    current_tab = get_active_tab(socket)

    socket =
      if current_tab.sql == "" && current_tab.data_source_id == nil do
        # Reuse current empty tab
        updated = %{current_tab | sql: saved_query.sql, name: saved_query.title}
        put_tab(socket, updated)
      else
        # Create new tab
        counter = socket.assigns.tab_counter + 1
        tab = %{new_tab(saved_query.title) | sql: saved_query.sql}

        socket
        |> update(:tabs, &Map.put(&1, tab.id, tab))
        |> update(:tab_order, &(&1 ++ [tab.id]))
        |> assign(active_tab_id: tab.id, tab_counter: counter)
      end

    socket = push_event(socket, "set_sql", %{sql: saved_query.sql})

    if saved_query.data_source_id do
      ds_id = saved_query.data_source_id
      runs = Querying.list_recent_runs(scope, ds_id)
      schema_map = load_schema_map(scope, ds_id)

      tab = socket.assigns.tabs[socket.assigns.active_tab_id]
      updated = %{tab | data_source_id: ds_id, result: nil, error: nil}

      socket
      |> put_tab(updated)
      |> stream(:history, runs, reset: true)
      |> push_event("set_catalog", %{schema: schema_map})
    else
      socket
    end
  end

  defp execute_sql(socket) do
    scope = socket.assigns.current_scope
    tab = get_active_tab(socket)
    data_source = DataSources.get_data_source!(scope, tab.data_source_id)
    cancel_ref = Ecto.UUID.generate()

    cancel_timeout(tab.timeout_ref)
    timeout_ref = Process.send_after(self(), {:query_timeout, tab.id}, @query_timeout_ms)

    updated = %{
      tab
      | running?: true,
        result: nil,
        error: nil,
        show_params_form?: false,
        timeout_ref: timeout_ref,
        cancel_ref: cancel_ref
    }

    socket =
      socket
      |> put_tab(updated)
      |> start_async({:execute_query, tab.id}, fn ->
        Querying.execute_query(scope, data_source, tab.execute_sql, tab.param_values,
          cancel_ref: cancel_ref,
          row_limit: tab.row_limit
        )
      end)

    {:noreply, socket}
  end

  defp maybe_refresh_history(socket, tab_id) do
    if tab_id == socket.assigns.active_tab_id do
      tab = socket.assigns.tabs[tab_id]

      case tab.data_source_id do
        nil ->
          socket

        ds_id ->
          scope = socket.assigns.current_scope
          runs = Querying.list_recent_runs(scope, ds_id)
          stream(socket, :history, runs, reset: true)
      end
    else
      socket
    end
  end

  defp load_schema_map(scope, ds_id) do
    case Catalog.autocomplete_schema(scope, ds_id) do
      map when is_map(map) -> map
      _ -> %{}
    end
  end

  defp cancel_timeout(nil), do: :ok
  defp cancel_timeout(ref), do: Process.cancel_timer(ref)

  defp format_cell(nil), do: "NULL"
  defp format_cell(true), do: "true"
  defp format_cell(false), do: "false"
  defp format_cell(%Decimal{} = value), do: Decimal.to_string(value)
  defp format_cell(%Date{} = value), do: Date.to_string(value)
  defp format_cell(%DateTime{} = value), do: DateTime.to_string(value)
  defp format_cell(%NaiveDateTime{} = value), do: NaiveDateTime.to_string(value)
  defp format_cell(%Time{} = value), do: Time.to_string(value)

  defp format_cell(value) when is_binary(value) do
    if String.length(value) > 500 do
      String.slice(value, 0, 500) <> "..."
    else
      value
    end
  end

  defp format_cell(value) when is_number(value), do: to_string(value)
  defp format_cell(value), do: inspect(value)

  defp truncated?(value) when is_binary(value), do: String.length(value) > 500
  defp truncated?(_), do: false

  defp raw_cell(value) when is_binary(value), do: value
  defp raw_cell(value), do: inspect(value)

  defp sort_rows(rows, nil, _direction), do: rows

  defp sort_rows(rows, column, direction) do
    sorted =
      Enum.sort_by(rows, fn row ->
        val = Enum.at(row, column)
        sort_key(val)
      end)

    if direction == :desc, do: Enum.reverse(sorted), else: sorted
  end

  defp sort_key(nil), do: {0, ""}
  defp sort_key(val) when is_number(val), do: {1, val}
  defp sort_key(%Decimal{} = val), do: {1, Decimal.to_float(val)}
  defp sort_key(val) when is_binary(val), do: {2, String.downcase(val)}
  defp sort_key(val), do: {3, to_string(val)}
end
