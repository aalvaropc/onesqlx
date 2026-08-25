defmodule OnesqlxWeb.SqlEditorLive.Components do
  @moduledoc """
  Function components for the SQL editor: tab bar, toolbar, parameter
  form, results area, side panel, and modals. Markup only — all state
  and events stay in `OnesqlxWeb.SqlEditorLive`.
  """

  use OnesqlxWeb, :html

  import OnesqlxWeb.CellFormatter

  alias Onesqlx.Querying.Params

  attr :tabs, :map, required: true
  attr :tab_order, :list, required: true
  attr :active_tab_id, :string, required: true

  def tab_bar(assigns) do
    ~H"""
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
    """
  end

  attr :tab, :map, required: true
  attr :data_sources, :list, required: true

  def toolbar(assigns) do
    ~H"""
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

      <div :if={@tab.result && @tab.data_source_id} class="dropdown dropdown-end">
        <div tabindex="0" role="button" class="btn btn-sm">
          <.icon name="hero-arrow-down-tray" class="size-4" /> Export
        </div>
        <ul
          tabindex="0"
          class="dropdown-content menu bg-base-100 rounded-box z-10 w-36 p-1 shadow border border-base-300"
        >
          <li :for={
            {label, path} <- [
              {"CSV", ~p"/exports/csv"},
              {"JSON", ~p"/exports/json"},
              {"Excel", ~p"/exports/xlsx"}
            ]
          }>
            <form action={path} method="post">
              <input
                type="hidden"
                name="_csrf_token"
                value={Plug.CSRFProtection.get_csrf_token()}
              />
              <input type="hidden" name="data_source_id" value={@tab.data_source_id} />
              <%!-- The SQL that produced @tab.result, not the live buffer --%>
              <input type="hidden" name="sql" value={@tab.execute_sql} />
              <input type="hidden" name="label" value="sql_editor" />
              <input
                :for={{name, value} <- @tab.param_values}
                type="hidden"
                name={"params[#{name}]"}
                value={value}
              />
              <button type="submit" class="w-full text-left text-sm">{label}</button>
            </form>
          </li>
        </ul>
      </div>

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
    """
  end

  attr :tab, :map, required: true

  def params_form(assigns) do
    ~H"""
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
    """
  end

  attr :tab, :map, required: true

  def results_area(assigns) do
    ~H"""
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
                <tr :for={row <- sort_rows(@tab.result.rows, @tab.sort_column, @tab.sort_direction)}>
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
    """
  end

  attr :tab, :map, required: true
  attr :side_panel_tab, :atom, required: true
  attr :history, :any, required: true, doc: "the :history LiveView stream"
  attr :snippets, :list, required: true

  def side_panel(assigns) do
    ~H"""
    <div class="hidden lg:flex w-72 flex-shrink-0 flex-col min-h-0 border-l border-base-300 pl-4">
      <div class="flex items-center gap-2 mb-2">
        <button
          phx-click="set_side_tab"
          phx-value-tab="history"
          class={["btn btn-xs", @side_panel_tab == :history && "btn-active"]}
        >
          History
        </button>
        <button
          phx-click="set_side_tab"
          phx-value-tab="snippets"
          class={["btn btn-xs", @side_panel_tab == :snippets && "btn-active"]}
        >
          Snippets
        </button>
      </div>

      <div :if={@side_panel_tab == :history} class="flex-1 overflow-y-auto space-y-2">
        <div
          :for={{dom_id, run} <- @history}
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
        <p :if={@tab.data_source_id == nil} class="text-xs text-base-content/50">
          Select a data source to view history.
        </p>
      </div>

      <div :if={@side_panel_tab == :snippets} class="flex-1 overflow-y-auto space-y-2">
        <button phx-click="open_snippet_modal" class="btn btn-xs btn-primary w-full mb-2">
          <.icon name="hero-plus" class="size-3" /> New Snippet
        </button>
        <div
          :for={snippet <- @snippets}
          class="p-2 border border-base-300 rounded"
        >
          <div class="flex items-center justify-between mb-1">
            <span class="text-xs font-semibold truncate">{snippet.title}</span>
            <div class="flex items-center gap-0.5">
              <button
                phx-click="insert_snippet"
                phx-value-sql={snippet.sql}
                class="btn btn-ghost btn-xs px-1"
                title="Insert into editor"
              >
                <.icon name="hero-arrow-down-on-square" class="size-3" />
              </button>
              <button
                phx-click="delete_snippet"
                phx-value-id={snippet.id}
                data-confirm="Delete this snippet?"
                class="btn btn-ghost btn-xs px-1 text-error"
                title="Delete"
              >
                <.icon name="hero-trash" class="size-3" />
              </button>
            </div>
          </div>
          <p class="text-xs font-mono truncate text-base-content/60">{snippet.sql}</p>
        </div>
        <p :if={@snippets == []} class="text-xs text-base-content/50">
          No snippets yet. Save reusable SQL here.
        </p>
      </div>
    </div>
    """
  end

  attr :show?, :boolean, required: true
  attr :form, :any, required: true

  def save_modal(assigns) do
    ~H"""
    <div
      :if={@show?}
      role="dialog"
      aria-modal="true"
      class="fixed inset-0 z-50 flex items-center justify-center"
    >
      <div class="fixed inset-0 bg-black/50" phx-click="close_save_modal"></div>
      <div class="relative bg-base-100 rounded-lg p-6 w-full max-w-md shadow-xl">
        <h3 class="text-lg font-semibold mb-4">Save Query</h3>
        <.form
          for={@form}
          id="save-query-form"
          phx-submit="save_query"
          phx-change="validate_save"
        >
          <.input field={@form[:title]} type="text" label="Title" required />
          <.input field={@form[:description]} type="textarea" label="Description (optional)" />
          <div class="flex justify-end gap-2 mt-4">
            <button type="button" phx-click="close_save_modal" class="btn btn-sm">
              Cancel
            </button>
            <.button variant="primary" phx-disable-with="Saving...">Save</.button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  attr :viewing_cell, :string, default: nil

  def cell_view_modal(assigns) do
    ~H"""
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
    """
  end

  attr :show?, :boolean, required: true
  attr :form, :any, required: true

  def snippet_modal(assigns) do
    ~H"""
    <div
      :if={@show?}
      role="dialog"
      aria-modal="true"
      class="fixed inset-0 z-50 flex items-center justify-center"
    >
      <div class="fixed inset-0 bg-black/50" phx-click="close_snippet_modal"></div>
      <div class="relative bg-base-100 rounded-lg p-6 w-full max-w-md shadow-xl">
        <h3 class="text-lg font-semibold mb-4">Save Snippet</h3>
        <.form
          for={@form}
          id="snippet-form"
          phx-submit="create_snippet"
        >
          <.input field={@form[:title]} type="text" label="Title" required />
          <.input field={@form[:description]} type="text" label="Description (optional)" />
          <.input field={@form[:sql]} type="textarea" label="SQL" required />
          <div class="flex justify-end gap-2 mt-4">
            <button type="button" phx-click="close_snippet_modal" class="btn btn-sm">Cancel</button>
            <.button variant="primary" phx-disable-with="Saving...">Save</.button>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
