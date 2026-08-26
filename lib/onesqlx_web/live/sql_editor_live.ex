defmodule OnesqlxWeb.SqlEditorLive do
  @moduledoc """
  LiveView for the SQL Editor with multi-tab support.

  Each tab maintains its own SQL, data source, results, and execution state.
  A single CodeMirror instance swaps content on tab switch.

  Markup lives in `OnesqlxWeb.SqlEditorLive.Components`; pure tab-state
  helpers in `OnesqlxWeb.SqlEditorLive.Tabs`.
  """

  use OnesqlxWeb, :live_view

  import OnesqlxWeb.SqlEditorLive.Components

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
  alias Onesqlx.Snippets
  alias Onesqlx.Snippets.SqlSnippet
  alias OnesqlxWeb.SqlEditorLive.Tabs

  # -- Render ------------------------------------------------------------------

  @impl true
  def render(assigns) do
    tab = assigns.tabs[assigns.active_tab_id]
    assigns = assign(assigns, :tab, tab)

    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} wide>
      <div class="flex flex-col h-[calc(100vh-10rem)]">
        <.tab_bar tabs={@tabs} tab_order={@tab_order} active_tab_id={@active_tab_id} />
        <.toolbar tab={@tab} data_sources={@data_sources} />

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

            <.params_form tab={@tab} />
            <.results_area tab={@tab} />
          </div>

          <.side_panel
            tab={@tab}
            side_panel_tab={@side_panel_tab}
            history={@streams.history}
            snippets={@snippets}
          />
        </div>
      </div>
      <.save_modal show?={@show_save_modal?} form={@save_form} />
      <.cell_view_modal viewing_cell={@viewing_cell} />
      <.snippet_modal show?={@show_snippet_modal?} form={@snippet_form} />
    </Layouts.app>
    """
  end

  # -- Mount -------------------------------------------------------------------

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    data_sources = DataSources.list_data_sources(scope)
    tab = Tabs.new("Tab 1")

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
        viewing_cell: nil,
        side_panel_tab: :history,
        snippets: Snippets.list_snippets(scope),
        show_snippet_modal?: false,
        snippet_form: nil
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
    tab = Tabs.new("Tab #{counter}")

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

      new_active =
        Tabs.next_active_after_close(
          socket.assigns.tab_order,
          socket.assigns.active_tab_id,
          tab_id
        )

      new_order = Enum.reject(socket.assigns.tab_order, &(&1 == tab_id))
      new_tabs = Map.delete(socket.assigns.tabs, tab_id)

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

  @row_limit_options ~w(100 500 1000 5000 10000)

  def handle_event("set_row_limit", %{"row_limit" => limit_str}, socket) do
    # Allowlist the select's options rather than trusting client input
    if limit_str in @row_limit_options do
      tab = get_active_tab(socket)
      updated = %{tab | row_limit: String.to_integer(limit_str)}
      {:noreply, put_tab(socket, updated)}
    else
      {:noreply, socket}
    end
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

  # -- Side Panel & Snippets ---------------------------------------------------

  def handle_event("set_side_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, side_panel_tab: String.to_existing_atom(tab))}
  end

  def handle_event("insert_snippet", %{"sql" => sql}, socket) do
    tab = get_active_tab(socket)
    new_sql = if tab.sql == "", do: sql, else: tab.sql <> "\n" <> sql
    updated = %{tab | sql: new_sql}

    socket =
      socket
      |> put_tab(updated)
      |> push_event("set_sql", %{sql: new_sql})

    {:noreply, socket}
  end

  def handle_event("open_snippet_modal", _params, socket) do
    tab = get_active_tab(socket)
    changeset = Snippets.change_snippet(%SqlSnippet{}, %{sql: tab.sql})

    {:noreply,
     assign(socket, show_snippet_modal?: true, snippet_form: to_form(changeset, as: "snippet"))}
  end

  def handle_event("close_snippet_modal", _params, socket) do
    {:noreply, assign(socket, show_snippet_modal?: false, snippet_form: nil)}
  end

  def handle_event("create_snippet", %{"snippet" => params}, socket) do
    scope = socket.assigns.current_scope

    case Snippets.create_snippet(scope, params) do
      {:ok, _snippet} ->
        snippets = Snippets.list_snippets(scope)

        {:noreply,
         socket
         |> assign(snippets: snippets, show_snippet_modal?: false, snippet_form: nil)
         |> put_flash(:info, "Snippet saved.")}

      {:error, changeset} ->
        {:noreply, assign(socket, snippet_form: to_form(changeset, as: "snippet"))}
    end
  end

  def handle_event("delete_snippet", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    {:ok, _} = Snippets.delete_snippet(scope, id)
    snippets = Snippets.list_snippets(scope)
    {:noreply, assign(socket, snippets: snippets)}
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
        tab = %{Tabs.new(saved_query.title) | sql: saved_query.sql}

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
end
