defmodule OnesqlxWeb.DashboardLive.ShowComponents do
  @moduledoc """
  Function components for the dashboard show view: header toolbar,
  filter bar, card grid, and modals. Markup only — state and events
  stay in `OnesqlxWeb.DashboardLive.Show`; the card body itself comes
  from `OnesqlxWeb.DashboardLive.CardHelpers.card_content/1`.
  """

  use OnesqlxWeb, :html

  import OnesqlxWeb.DashboardLive.CardHelpers, only: [card_content: 1, card_span_class: 1]

  alias Onesqlx.Querying.Params

  attr :dashboard, :map, required: true
  attr :dashboard_param_names, :list, required: true
  attr :dashboard_params, :map, required: true
  attr :auto_refresh_interval, :integer, required: true
  attr :editing?, :boolean, required: true

  def toolbar(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center gap-2 md:gap-4 mb-6">
      <h1 class="text-2xl font-bold flex-1">{@dashboard.title}</h1>

      <div :if={@dashboard_param_names != []} class="flex items-center gap-2">
        <div :for={param <- @dashboard_param_names} class="flex items-center gap-1">
          <label class="text-xs font-mono text-base-content/60">
            {param_label(@dashboard.variables, param)}
          </label>
          <input
            type={param_input_type(@dashboard.variables, param)}
            phx-blur="set_dashboard_param"
            phx-value-name={param}
            name={"params[#{param}]"}
            value={Map.get(@dashboard_params, param, "")}
            step={if param_input_type(@dashboard.variables, param) == "number", do: "any"}
            class="input input-bordered input-xs w-24"
          />
        </div>
        <button phx-click="apply_dashboard_params" class="btn btn-xs btn-primary">
          Apply
        </button>
      </div>

      <button :if={@editing?} phx-click="open_variables_modal" class="btn btn-sm">
        <.icon name="hero-variable" class="size-4" /> Variables
      </button>
      <button phx-click="refresh" class="btn btn-sm">
        <.icon name="hero-arrow-path" class="size-4" /> Refresh
      </button>
      <select
        phx-change="set_auto_refresh"
        name="interval"
        class="select select-bordered select-sm w-28"
      >
        <option value="0" selected={@auto_refresh_interval == 0}>Auto: Off</option>
        <option value="30000" selected={@auto_refresh_interval == 30_000}>30s</option>
        <option value="60000" selected={@auto_refresh_interval == 60_000}>1m</option>
        <option value="300000" selected={@auto_refresh_interval == 300_000}>5m</option>
        <option value="900000" selected={@auto_refresh_interval == 900_000}>15m</option>
      </select>
      <button phx-click="duplicate_dashboard" class="btn btn-sm">
        <.icon name="hero-document-duplicate" class="size-4" /> Duplicate
      </button>
      <button id="fullscreen-btn" phx-hook="Fullscreen" class="btn btn-sm">
        Fullscreen
      </button>
      <button phx-click="toggle_share" class="btn btn-sm">
        <.icon name="hero-share" class="size-4" /> Share
      </button>
      <button phx-click="toggle_edit" class={["btn btn-sm", @editing? && "btn-active"]}>
        {if @editing?, do: "Done", else: "Edit"}
      </button>
    </div>
    """
  end

  attr :active_filters, :map, required: true

  def filters_bar(assigns) do
    ~H"""
    <div :if={@active_filters != %{}} class="flex items-center gap-2 mb-3">
      <span class="text-xs text-base-content/60">Filters:</span>
      <span
        :for={{field, value} <- @active_filters}
        class="badge badge-sm badge-primary gap-1"
      >
        {field} = {value}
      </span>
      <button phx-click="clear_filters" class="btn btn-xs btn-ghost">
        <.icon name="hero-x-mark" class="size-3" /> Clear
      </button>
    </div>
    """
  end

  attr :dashboard, :map, required: true
  attr :card_results, :map, required: true
  attr :editing?, :boolean, required: true
  attr :dashboard_params, :map, default: %{}

  def card_grid(assigns) do
    ~H"""
    <div
      id="card-grid"
      phx-hook="SortableCards"
      data-editing={to_string(@editing?)}
      class="grid grid-cols-1 md:grid-cols-4 gap-4"
    >
      <div
        :for={card <- @dashboard.cards}
        id={"card-#{card.id}"}
        class={["card border border-base-300 p-4", card_span_class(card)]}
      >
        <div class="flex items-start justify-between mb-3">
          <div class="flex items-center gap-2">
            <div :if={@editing?} class="drag-handle cursor-grab active:cursor-grabbing">
              <.icon name="hero-bars-3" class="size-4 text-base-content/40" />
            </div>
            <h3 class="font-semibold">
              {card.title || (card.saved_query && card.saved_query.title) || "Untitled Card"}
            </h3>
          </div>
          <div :if={@editing?} class="flex items-center gap-1 ml-2 flex-shrink-0">
            <button
              phx-click="move_card_up"
              phx-value-id={card.id}
              class="btn btn-xs btn-ghost"
              aria-label="Move card up"
            >
              <.icon name="hero-arrow-up" class="size-3" />
            </button>
            <button
              phx-click="move_card_down"
              phx-value-id={card.id}
              class="btn btn-xs btn-ghost"
              aria-label="Move card down"
            >
              <.icon name="hero-arrow-down" class="size-3" />
            </button>
            <.link
              :if={card.saved_query_id}
              navigate={~p"/sql-editor?saved_query_id=#{card.saved_query_id}"}
              class="btn btn-xs btn-ghost"
              aria-label="Open in editor"
            >
              <.icon name="hero-arrow-top-right-on-square" class="size-3" />
            </.link>
            <div class="flex items-center border border-base-300 rounded text-xs">
              <button
                :for={span <- 1..4}
                phx-click="set_card_span"
                phx-value-id={card.id}
                phx-value-span={span}
                class={[
                  "px-1.5 py-0.5",
                  (card.config["span"] || 2) == span && "bg-primary text-primary-content rounded"
                ]}
              >
                {span}
              </button>
            </div>
            <button
              phx-click="remove_card"
              phx-value-id={card.id}
              data-confirm="Remove this card?"
              class="btn btn-xs btn-ghost text-error"
              aria-label="Remove card"
            >
              <.icon name="hero-x-mark" class="size-3" />
            </button>
          </div>
        </div>
        <.card_content
          card={card}
          result={Map.get(@card_results, card.id, :loading)}
          exportable?
          export_params={card_export_params(card, @dashboard_params)}
        />
      </div>
    </div>
    """
  end

  attr :show?, :boolean, required: true
  attr :form, :any, required: true
  attr :saved_queries, :list, required: true

  def add_card_modal(assigns) do
    ~H"""
    <div
      :if={@show?}
      class="fixed inset-0 z-50 flex items-center justify-center"
      role="dialog"
      aria-modal="true"
    >
      <div class="fixed inset-0 bg-black/50" phx-click="close_add_card_modal"></div>
      <div class="relative bg-base-100 rounded-lg p-6 w-full max-w-md shadow-xl">
        <h3 class="text-lg font-semibold mb-4">Add Card</h3>
        <.form
          for={@form}
          id="add-card-form"
          phx-submit="add_card"
          phx-change="validate_card"
        >
          <div class="form-control mb-4">
            <label class="label"><span class="label-text">Saved Query</span></label>
            <select name="card[saved_query_id]" class="select select-bordered w-full">
              <option value="">None</option>
              <option :for={q <- @saved_queries} value={q.id}>
                {q.title}
              </option>
            </select>
          </div>
          <div class="form-control mb-4">
            <label class="label"><span class="label-text">Type</span></label>
            <select name="card[type]" class="select select-bordered w-full">
              <option value="table">Table</option>
              <option value="kpi">KPI</option>
              <option value="bar">Bar Chart</option>
              <option value="line">Line Chart</option>
              <option value="pie">Pie Chart</option>
              <option value="doughnut">Doughnut Chart</option>
              <option value="area">Area Chart</option>
              <option value="scatter">Scatter Plot</option>
              <option value="markdown">Text / Markdown</option>
            </select>
          </div>
          <.input field={@form[:title]} type="text" label="Title (optional)" />
          <div class="flex gap-2 mt-2">
            <div class="form-control flex-1">
              <label class="label"><span class="label-text text-xs">Prefix (e.g. $)</span></label>
              <input
                type="text"
                name="card[config][prefix]"
                placeholder="$"
                class="input input-bordered input-sm w-full"
              />
            </div>
            <div class="form-control flex-1">
              <label class="label"><span class="label-text text-xs">Suffix (e.g. %)</span></label>
              <input
                type="text"
                name="card[config][suffix]"
                placeholder="%"
                class="input input-bordered input-sm w-full"
              />
            </div>
          </div>
          <div class="form-control mt-2">
            <label class="label">
              <span class="label-text text-xs">Content (for Markdown cards)</span>
            </label>
            <textarea
              name="card[config][content]"
              placeholder="## Section Title&#10;&#10;Some explanatory text..."
              rows="3"
              class="textarea textarea-bordered textarea-sm w-full"
            ></textarea>
          </div>
          <div class="form-control mt-2">
            <label class="label">
              <span class="label-text text-xs">Filter Field (cross-filtering param name)</span>
            </label>
            <input
              type="text"
              name="card[config][filter_field]"
              placeholder="e.g. category"
              class="input input-bordered input-sm w-full"
            />
          </div>
          <div class="flex justify-end gap-2 mt-4">
            <button type="button" phx-click="close_add_card_modal" class="btn btn-sm">
              Cancel
            </button>
            <.button variant="primary" phx-disable-with="Adding...">Add</.button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  attr :show?, :boolean, required: true
  attr :variables, :list, required: true

  def variables_modal(assigns) do
    ~H"""
    <div
      :if={@show?}
      role="dialog"
      aria-modal="true"
      class="fixed inset-0 z-50 flex items-center justify-center"
    >
      <div class="fixed inset-0 bg-black/50" phx-click="close_variables_modal"></div>
      <div class="relative bg-base-100 rounded-lg p-6 w-full max-w-lg shadow-xl">
        <h3 class="text-lg font-semibold mb-1">Dashboard Variables</h3>
        <p class="text-xs text-base-content/60 mb-4">
          Variables map to <span class="font-mono">:name</span>
          parameters in the cards' queries. They appear in the filter bar
          — also on public and embedded views via <span class="font-mono">?name=value</span>
          in the URL.
        </p>

        <div :if={@variables != []} class="space-y-2 mb-4">
          <div
            :for={var <- @variables}
            class="flex items-center gap-2 p-2 border border-base-300 rounded"
          >
            <span class="font-mono text-sm flex-1">:{var["name"]}</span>
            <span class="badge badge-sm">{var["type"]}</span>
            <span :if={var["default"] not in [nil, ""]} class="text-xs text-base-content/60">
              default: {var["default"]}
            </span>
            <button
              phx-click="remove_variable"
              phx-value-name={var["name"]}
              class="btn btn-ghost btn-xs text-error"
              aria-label={"Remove variable #{var["name"]}"}
            >
              <.icon name="hero-trash" class="size-3" />
            </button>
          </div>
        </div>
        <p :if={@variables == []} class="text-sm text-base-content/50 mb-4">
          No variables defined yet.
        </p>

        <form phx-submit="add_variable" class="border-t border-base-300 pt-4">
          <div class="flex gap-2">
            <input
              type="text"
              name="variable[name]"
              placeholder="name"
              required
              pattern="[a-zA-Z_][a-zA-Z0-9_]*"
              class="input input-bordered input-sm flex-1 font-mono"
            />
            <select name="variable[type]" class="select select-bordered select-sm w-28">
              <option value="text">Text</option>
              <option value="number">Number</option>
              <option value="date">Date</option>
            </select>
            <input
              type="text"
              name="variable[default]"
              placeholder="default (optional)"
              class="input input-bordered input-sm flex-1"
            />
            <button type="submit" class="btn btn-sm btn-primary">Add</button>
          </div>
        </form>

        <div class="flex justify-end mt-4">
          <button phx-click="close_variables_modal" class="btn btn-sm">Close</button>
        </div>
      </div>
    </div>
    """
  end

  # The same merge the card execution uses (show.ex maybe_start_card_async),
  # so the export downloads exactly what the card shows.
  defp card_export_params(card, dashboard_params) do
    card_params = get_in(card.config, ["params"]) || %{}
    Map.merge(card_params, dashboard_params || %{})
  end

  defp param_input_type(variables, param) do
    case Enum.find(variables || [], &(&1["name"] == param)) do
      %{"type" => "number"} -> "number"
      %{"type" => "date"} -> "date"
      %{"type" => _} -> "text"
      nil -> Params.infer_input_type(param)
    end
  end

  defp param_label(variables, param) do
    case Enum.find(variables || [], &(&1["name"] == param)) do
      %{"label" => label} when label not in [nil, ""] -> label
      _ -> ":#{param}"
    end
  end

  attr :show?, :boolean, required: true
  attr :dashboard, :map, required: true

  def share_modal(assigns) do
    ~H"""
    <div
      :if={@show?}
      role="dialog"
      aria-modal="true"
      class="fixed inset-0 z-50 flex items-center justify-center"
    >
      <div class="fixed inset-0 bg-black/50" phx-click="toggle_share"></div>
      <div class="relative bg-base-100 rounded-lg p-6 w-full max-w-md shadow-xl">
        <h3 class="text-lg font-semibold mb-4">Share Dashboard</h3>
        <div :if={@dashboard.public_token}>
          <p class="text-sm text-base-content/60 mb-2">
            Public link (anyone with this link can view):
          </p>
          <div class="bg-base-200 rounded p-3 font-mono text-sm break-all select-all mb-3">
            {url(~p"/share/#{@dashboard.public_token}")}
          </div>
          <p class="text-sm text-base-content/60 mb-2">
            Embed in your site or app:
          </p>
          <div class="bg-base-200 rounded p-3 font-mono text-xs break-all select-all mb-4">
            {"<iframe src=\"#{url(~p"/embed/#{@dashboard.public_token}")}\" width=\"100%\" height=\"600\" frameborder=\"0\"></iframe>"}
          </div>
          <button phx-click="revoke_share" class="btn btn-sm btn-error">Revoke Link</button>
        </div>
        <div :if={!@dashboard.public_token}>
          <p class="text-sm text-base-content/60 mb-4">
            Generate a public link to share this dashboard without requiring login.
          </p>
          <button phx-click="generate_share" class="btn btn-sm btn-primary">Generate Link</button>
        </div>
        <div class="flex justify-end mt-4">
          <button phx-click="toggle_share" class="btn btn-sm">Close</button>
        </div>
      </div>
    </div>
    """
  end
end
