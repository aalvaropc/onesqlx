defmodule OnesqlxWeb.DashboardLive.Show do
  @moduledoc """
  LiveView for viewing and editing a dashboard, with async per-card query execution.
  """

  use OnesqlxWeb, :live_view

  @query_timeout_ms 60_000
  @timeout_message "Query timed out after 60 seconds. The database may still be processing the query."

  alias Onesqlx.Dashboards
  alias Onesqlx.Dashboards.CardRenderer
  alias Onesqlx.Dashboards.DashboardCard
  alias Onesqlx.Querying.Executor
  alias Onesqlx.Querying.Params
  alias Onesqlx.SavedQueries

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex flex-wrap items-center gap-2 md:gap-4 mb-6">
        <.link navigate={~p"/dashboards"} class="btn btn-sm btn-ghost">
          <.icon name="hero-arrow-left" class="size-4" /> Back
        </.link>
        <h1 class="text-2xl font-bold flex-1">{@dashboard.title}</h1>

        <div :if={@dashboard_param_names != []} class="flex items-center gap-2">
          <div :for={param <- @dashboard_param_names} class="flex items-center gap-1">
            <label class="text-xs font-mono text-base-content/60">:{param}</label>
            <input
              type="text"
              phx-blur="set_dashboard_param"
              phx-value-name={param}
              name={"params[#{param}]"}
              value={Map.get(@dashboard_params, param, "")}
              class="input input-bordered input-xs w-24"
            />
          </div>
          <button phx-click="apply_dashboard_params" class="btn btn-xs btn-primary">
            Apply
          </button>
        </div>

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
        <button phx-click="toggle_share" class="btn btn-sm">
          <.icon name="hero-share" class="size-4" /> Share
        </button>
        <button phx-click="toggle_edit" class={["btn btn-sm", @editing? && "btn-active"]}>
          {if @editing?, do: "Done", else: "Edit"}
        </button>
      </div>

      <div
        id="card-grid"
        phx-hook="SortableCards"
        data-editing={to_string(@editing?)}
        class="grid grid-cols-1 md:grid-cols-2 gap-4"
      >
        <div
          :for={card <- @dashboard.cards}
          id={"card-#{card.id}"}
          class="card border border-base-300 p-4"
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
          <.card_content card={card} result={Map.get(@card_results, card.id, :loading)} />
        </div>
      </div>

      <div :if={@dashboard.cards == []} class="text-center py-12">
        <.icon name="hero-squares-plus" class="size-12 text-base-content/20 mx-auto mb-4" />
        <p class="text-base-content/60 mb-2">No cards yet</p>
        <p class="text-sm text-base-content/40">
          Click "Edit" then "Add Card" to add your first visualization.
        </p>
      </div>

      <div :if={@editing?} class="mt-6">
        <button phx-click="open_add_card_modal" class="btn btn-primary">
          <.icon name="hero-plus" class="size-4" /> Add Card
        </button>
      </div>

      <div
        :if={@show_add_card_modal?}
        class="fixed inset-0 z-50 flex items-center justify-center"
        role="dialog"
        aria-modal="true"
      >
        <div class="fixed inset-0 bg-black/50" phx-click="close_add_card_modal"></div>
        <div class="relative bg-base-100 rounded-lg p-6 w-full max-w-md shadow-xl">
          <h3 class="text-lg font-semibold mb-4">Add Card</h3>
          <.form
            for={@add_card_form}
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
              </select>
            </div>
            <.input field={@add_card_form[:title]} type="text" label="Title (optional)" />
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
            <div class="flex justify-end gap-2 mt-4">
              <button type="button" phx-click="close_add_card_modal" class="btn btn-sm">
                Cancel
              </button>
              <.button variant="primary" phx-disable-with="Adding...">Add</.button>
            </div>
          </.form>
        </div>
      </div>

      <div
        :if={@show_share_modal?}
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
    </Layouts.app>
    """
  end

  attr :card, :map, required: true
  attr :result, :any, required: true

  defp card_content(%{result: :loading} = assigns) do
    ~H"""
    <div class="flex items-center justify-center py-8">
      <span class="loading loading-spinner loading-md"></span>
    </div>
    """
  end

  defp card_content(%{result: {:error, _msg}} = assigns) do
    ~H"""
    <div class="alert alert-error text-sm">{elem(@result, 1)}</div>
    """
  end

  defp card_content(%{card: %{type: "kpi"} = card, result: {:ok, result}} = assigns) do
    kpi = CardRenderer.kpi_value_for(result)
    config = card.config || %{}

    formatted =
      case kpi do
        {value, label} -> {CardRenderer.format_kpi_value(value, config), label}
        nil -> nil
      end

    assigns = assign(assigns, :kpi, formatted)

    ~H"""
    <div :if={@kpi} class="text-center py-4">
      <p class="text-4xl font-bold">{elem(@kpi, 0)}</p>
      <p class="text-sm text-base-content/60 mt-1">{elem(@kpi, 1)}</p>
    </div>
    <div :if={!@kpi} class="text-center py-4 text-base-content/50 text-sm">No data</div>
    """
  end

  defp card_content(%{card: %{type: type}, result: {:ok, result}} = assigns)
       when type in ["bar", "line", "pie", "doughnut", "area", "scatter"] do
    chart_data = CardRenderer.chart_data_for(result)
    assigns = assign(assigns, chart_data: Jason.encode!(chart_data), chart_type: type)

    ~H"""
    <div
      id={"chart-#{@card.id}"}
      phx-hook="ChartCard"
      data-chart-type={@chart_type}
      data-chart-data={@chart_data}
      class="h-48"
    >
      <canvas></canvas>
    </div>
    """
  end

  defp card_content(%{result: {:ok, result}} = assigns) do
    rows = Enum.take(result.rows, 20)
    assigns = assign(assigns, columns: result.columns, rows: rows, total: result.row_count)

    ~H"""
    <div class="overflow-x-auto">
      <table class="table table-xs">
        <thead>
          <tr>
            <th :for={col <- @columns}>{col}</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={row <- @rows}>
            <td :for={cell <- row} class="font-mono text-xs">{format_cell(cell)}</td>
          </tr>
        </tbody>
      </table>
      <p :if={length(@rows) < @total} class="text-xs text-base-content/50 mt-1">
        Showing {length(@rows)} of {@total} rows
      </p>
      <form
        :if={@card.saved_query && @card.saved_query.data_source_id}
        action={~p"/exports/csv"}
        method="post"
        class="mt-2"
      >
        <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
        <input type="hidden" name="data_source_id" value={@card.saved_query.data_source_id} />
        <input type="hidden" name="sql" value={@card.saved_query.sql} />
        <input type="hidden" name="label" value={@card.title || @card.saved_query.title || "export"} />
        <button type="submit" class="btn btn-xs">
          <.icon name="hero-arrow-down-tray" class="size-3" /> CSV
        </button>
      </form>
    </div>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    scope = socket.assigns.current_scope
    dashboard = Dashboards.get_dashboard_with_cards!(scope, id)

    card_results =
      Map.new(dashboard.cards, fn card ->
        {card.id, initial_card_result(card)}
      end)

    all_param_names = extract_dashboard_params(dashboard.cards)

    socket =
      socket
      |> assign(
        dashboard: dashboard,
        card_results: card_results,
        card_timeouts: %{},
        editing?: false,
        show_add_card_modal?: false,
        add_card_form: nil,
        saved_queries: [],
        auto_refresh_interval: 0,
        auto_refresh_ref: nil,
        show_share_modal?: false,
        dashboard_param_names: all_param_names,
        dashboard_params: %{},
        skip_cache?: false
      )
      |> start_card_async_tasks(dashboard.cards)

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_share", _params, socket) do
    {:noreply, assign(socket, show_share_modal?: !socket.assigns.show_share_modal?)}
  end

  def handle_event("generate_share", _params, socket) do
    scope = socket.assigns.current_scope
    {:ok, updated} = Dashboards.generate_public_token(scope, socket.assigns.dashboard)
    {:noreply, assign(socket, dashboard: updated)}
  end

  def handle_event("revoke_share", _params, socket) do
    scope = socket.assigns.current_scope
    {:ok, updated} = Dashboards.revoke_public_token(scope, socket.assigns.dashboard)
    {:noreply, assign(socket, dashboard: updated)}
  end

  def handle_event("toggle_edit", _params, socket) do
    {:noreply, assign(socket, editing?: !socket.assigns.editing?)}
  end

  def handle_event("refresh", _params, socket) do
    scope = socket.assigns.current_scope
    dashboard = Dashboards.get_dashboard_with_cards!(scope, socket.assigns.dashboard.id)

    cancel_all_card_timeouts(socket.assigns.card_timeouts)

    card_results =
      Map.new(dashboard.cards, fn card ->
        {card.id, initial_card_result(card)}
      end)

    socket =
      socket
      |> assign(
        dashboard: dashboard,
        card_results: card_results,
        card_timeouts: %{},
        skip_cache?: true
      )
      |> start_card_async_tasks(dashboard.cards)
      |> assign(skip_cache?: false)

    {:noreply, socket}
  end

  def handle_event("set_dashboard_param", %{"name" => name, "value" => value}, socket) do
    params = Map.put(socket.assigns.dashboard_params, name, value)
    {:noreply, assign(socket, dashboard_params: params)}
  end

  def handle_event("apply_dashboard_params", _params, socket) do
    scope = socket.assigns.current_scope
    dashboard = Dashboards.get_dashboard_with_cards!(scope, socket.assigns.dashboard.id)

    cancel_all_card_timeouts(socket.assigns.card_timeouts)

    card_results =
      Map.new(dashboard.cards, fn card ->
        {card.id, initial_card_result(card)}
      end)

    socket =
      socket
      |> assign(dashboard: dashboard, card_results: card_results, card_timeouts: %{})
      |> start_card_async_tasks(dashboard.cards)

    {:noreply, socket}
  end

  def handle_event("set_auto_refresh", %{"interval" => interval_str}, socket) do
    interval = String.to_integer(interval_str)

    if socket.assigns.auto_refresh_ref do
      Process.cancel_timer(socket.assigns.auto_refresh_ref)
    end

    ref =
      if interval > 0 do
        Process.send_after(self(), :auto_refresh, interval)
      end

    {:noreply, assign(socket, auto_refresh_interval: interval, auto_refresh_ref: ref)}
  end

  def handle_event("open_add_card_modal", _params, socket) do
    scope = socket.assigns.current_scope
    saved_queries = SavedQueries.list_saved_queries(scope)
    changeset = Dashboards.change_card(%DashboardCard{})

    socket =
      assign(socket,
        saved_queries: saved_queries,
        show_add_card_modal?: true,
        add_card_form: to_form(changeset, as: "card")
      )

    {:noreply, socket}
  end

  def handle_event("close_add_card_modal", _params, socket) do
    {:noreply, assign(socket, show_add_card_modal?: false, add_card_form: nil)}
  end

  def handle_event("validate_card", %{"card" => params}, socket) do
    changeset =
      %DashboardCard{}
      |> Dashboards.change_card(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, add_card_form: to_form(changeset, as: "card"))}
  end

  def handle_event("add_card", %{"card" => params}, socket) do
    scope = socket.assigns.current_scope
    dashboard = socket.assigns.dashboard

    case Dashboards.add_card(scope, dashboard, params) do
      {:ok, _card} ->
        dashboard = Dashboards.get_dashboard_with_cards!(scope, dashboard.id)
        new_card = List.last(dashboard.cards)

        card_results =
          socket.assigns.card_results
          |> Map.put(new_card.id, initial_card_result(new_card))

        socket =
          socket
          |> assign(
            dashboard: dashboard,
            card_results: card_results,
            show_add_card_modal?: false,
            add_card_form: nil
          )
          |> maybe_start_card_async(new_card)

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, add_card_form: to_form(changeset, as: "card"))}
    end
  end

  def handle_event("remove_card", %{"id" => card_id}, socket) do
    scope = socket.assigns.current_scope

    case Enum.find(socket.assigns.dashboard.cards, &(&1.id == card_id)) do
      nil ->
        {:noreply, socket}

      card ->
        {:ok, _} = Dashboards.remove_card(scope, card)
        dashboard = Dashboards.get_dashboard_with_cards!(scope, socket.assigns.dashboard.id)
        {:noreply, assign(socket, dashboard: dashboard)}
    end
  end

  def handle_event("move_card_up", %{"id" => card_id}, socket) do
    scope = socket.assigns.current_scope

    case Enum.find(socket.assigns.dashboard.cards, &(&1.id == card_id)) do
      nil ->
        {:noreply, socket}

      card ->
        {:ok, _} = Dashboards.move_card_up(scope, card)
        dashboard = Dashboards.get_dashboard_with_cards!(scope, socket.assigns.dashboard.id)
        {:noreply, assign(socket, dashboard: dashboard)}
    end
  end

  def handle_event("move_card_down", %{"id" => card_id}, socket) do
    scope = socket.assigns.current_scope

    case Enum.find(socket.assigns.dashboard.cards, &(&1.id == card_id)) do
      nil ->
        {:noreply, socket}

      card ->
        {:ok, _} = Dashboards.move_card_down(scope, card)
        dashboard = Dashboards.get_dashboard_with_cards!(scope, socket.assigns.dashboard.id)
        {:noreply, assign(socket, dashboard: dashboard)}
    end
  end

  def handle_event("reorder_cards", %{"ids" => card_ids}, socket) do
    scope = socket.assigns.current_scope
    dashboard = socket.assigns.dashboard

    Dashboards.reorder_cards(scope, dashboard, card_ids)
    dashboard = Dashboards.get_dashboard_with_cards!(scope, dashboard.id)
    {:noreply, assign(socket, dashboard: dashboard)}
  end

  @impl true
  def handle_async({:execute_card, id}, {:ok, {:ok, result}}, socket) do
    if Map.get(socket.assigns.card_results, id) == :loading do
      cancel_card_timeout(socket, id)

      socket =
        socket
        |> update(:card_results, &Map.put(&1, id, {:ok, result}))
        |> update(:card_timeouts, &Map.delete(&1, id))

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_async({:execute_card, id}, {:ok, {:error, _type, msg}}, socket) do
    if Map.get(socket.assigns.card_results, id) == :loading do
      cancel_card_timeout(socket, id)

      socket =
        socket
        |> update(:card_results, &Map.put(&1, id, {:error, msg}))
        |> update(:card_timeouts, &Map.delete(&1, id))

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_async({:execute_card, id}, {:exit, reason}, socket) do
    if Map.get(socket.assigns.card_results, id) == :loading do
      cancel_card_timeout(socket, id)
      msg = "Query process crashed: #{inspect(reason)}"

      socket =
        socket
        |> update(:card_results, &Map.put(&1, id, {:error, msg}))
        |> update(:card_timeouts, &Map.delete(&1, id))

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:card_timeout, card_id}, socket) do
    if Map.get(socket.assigns.card_results, card_id) == :loading do
      socket =
        socket
        |> update(:card_results, &Map.put(&1, card_id, {:error, @timeout_message}))
        |> update(:card_timeouts, &Map.delete(&1, card_id))

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:auto_refresh, socket) do
    interval = socket.assigns.auto_refresh_interval

    if interval > 0 do
      scope = socket.assigns.current_scope
      dashboard = Dashboards.get_dashboard_with_cards!(scope, socket.assigns.dashboard.id)

      cancel_all_card_timeouts(socket.assigns.card_timeouts)

      card_results =
        Map.new(dashboard.cards, fn card ->
          {card.id, initial_card_result(card)}
        end)

      ref = Process.send_after(self(), :auto_refresh, interval)

      socket =
        socket
        |> assign(
          dashboard: dashboard,
          card_results: card_results,
          card_timeouts: %{},
          auto_refresh_ref: ref
        )
        |> start_card_async_tasks(dashboard.cards)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp extract_dashboard_params(cards) do
    cards
    |> Enum.flat_map(fn
      %{saved_query: %{sql: sql}} when is_binary(sql) -> Params.extract(sql)
      _ -> []
    end)
    |> Enum.uniq()
  end

  defp initial_card_result(%{saved_query: %{data_source: %{}} = _sq}), do: :loading
  defp initial_card_result(_card), do: {:error, "No query assigned"}

  defp start_card_async_tasks(socket, cards) do
    Enum.reduce(cards, socket, &maybe_start_card_async(&2, &1))
  end

  @default_cache_ttl 300_000

  defp maybe_start_card_async(socket, card) do
    case card do
      %{saved_query: %{data_source: data_source, sql: sql}} when not is_nil(data_source) ->
        card_params = get_in(card.config, ["params"]) || %{}
        dashboard_params = socket.assigns.dashboard_params || %{}
        merged_params = Map.merge(card_params, dashboard_params)
        skip_cache? = socket.assigns[:skip_cache?] || false
        ref = Process.send_after(self(), {:card_timeout, card.id}, @query_timeout_ms)

        socket
        |> update(:card_timeouts, &Map.put(&1, card.id, ref))
        |> start_async({:execute_card, card.id}, fn ->
          Executor.execute(data_source, sql,
            params: merged_params,
            cache_ttl: @default_cache_ttl,
            skip_cache: skip_cache?
          )
        end)

      _ ->
        socket
    end
  end

  defp cancel_card_timeout(socket, card_id) do
    case Map.get(socket.assigns.card_timeouts, card_id) do
      nil -> :ok
      ref -> Process.cancel_timer(ref)
    end
  end

  defp cancel_all_card_timeouts(card_timeouts) do
    Enum.each(card_timeouts, fn {_id, ref} -> Process.cancel_timer(ref) end)
  end

  defp format_cell(nil), do: "NULL"
  defp format_cell(true), do: "true"
  defp format_cell(false), do: "false"
  defp format_cell(%Decimal{} = value), do: Decimal.to_string(value)
  defp format_cell(%Date{} = value), do: Date.to_string(value)
  defp format_cell(%DateTime{} = value), do: DateTime.to_string(value)
  defp format_cell(%NaiveDateTime{} = value), do: NaiveDateTime.to_string(value)
  defp format_cell(%Time{} = value), do: Time.to_string(value)

  defp format_cell(value) when is_binary(value) do
    if String.length(value) > 500, do: String.slice(value, 0, 500) <> "...", else: value
  end

  defp format_cell(value) when is_number(value), do: to_string(value)
  defp format_cell(value), do: inspect(value)
end
