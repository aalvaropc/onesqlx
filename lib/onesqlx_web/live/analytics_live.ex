defmodule OnesqlxWeb.AnalyticsLive do
  @moduledoc """
  LiveView for workspace usage analytics.
  """

  use OnesqlxWeb, :live_view

  alias Onesqlx.Audit

  @default_range 30

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Usage Analytics
        <:subtitle>Understand how your workspace uses OneSQLx.</:subtitle>
      </.header>

      <div class="flex items-center gap-2 mt-4 mb-6">
        <span class="text-sm text-base-content/60">Period:</span>
        <button
          :for={days <- [7, 30, 90]}
          phx-click="set_range"
          phx-value-days={days}
          class={["btn btn-sm", @range_days == days && "btn-active"]}
        >
          {days}d
        </button>
      </div>

      <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
        <div class="card border border-base-300 p-4 text-center">
          <p class="text-3xl font-bold">{@stats.total_executions}</p>
          <p class="text-sm text-base-content/60">Total Queries</p>
        </div>
        <div class="card border border-base-300 p-4 text-center">
          <p class="text-3xl font-bold">{success_rate(@stats)}%</p>
          <p class="text-sm text-base-content/60">Success Rate</p>
        </div>
        <div class="card border border-base-300 p-4 text-center">
          <p class="text-3xl font-bold">{@stats.avg_duration_ms}ms</p>
          <p class="text-sm text-base-content/60">Avg Duration</p>
        </div>
        <div class="card border border-base-300 p-4 text-center">
          <p class="text-3xl font-bold">{length(@active_users)}</p>
          <p class="text-sm text-base-content/60">Active Users</p>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h3 class="text-lg font-semibold mb-3">Slowest Queries</h3>
          <div class="space-y-2">
            <div
              :for={run <- @slowest_queries}
              class="card border border-base-300 p-3"
            >
              <p class="font-mono text-xs truncate">{String.slice(run.sql, 0, 120)}</p>
              <div class="flex items-center gap-3 mt-1 text-xs text-base-content/50">
                <span class="font-semibold text-warning">{run.duration_ms}ms</span>
                <span class={[
                  "badge badge-xs",
                  run.status == "success" && "badge-success",
                  run.status != "success" && "badge-error"
                ]}>
                  {run.status}
                </span>
              </div>
            </div>
            <p :if={@slowest_queries == []} class="text-sm text-base-content/50">No queries yet.</p>
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between mb-3">
            <h3 class="text-lg font-semibold">Recent Activity</h3>
            <form phx-change="filter_activity">
              <select name="event_type" class="select select-bordered select-xs w-40">
                <option value="">All events</option>
                <option
                  :for={t <- @event_types}
                  value={t}
                  selected={@filter_event_type == t}
                >
                  {t}
                </option>
              </select>
            </form>
          </div>
          <div id="activity" phx-update="stream" class="space-y-2">
            <div
              :for={{dom_id, event} <- @streams.activity}
              id={dom_id}
              class="card border border-base-300 p-3"
            >
              <div class="flex items-center gap-2">
                <span class="badge badge-xs badge-outline">{event.event_type}</span>
                <span :if={event.user} class="text-xs text-base-content/60">{event.user.email}</span>
                <span class="text-xs text-base-content/40 ml-auto">
                  {Calendar.strftime(event.occurred_at, "%m/%d %H:%M")}
                </span>
              </div>
            </div>
          </div>
          <p :if={!@has_activity?} class="text-sm text-base-content/50">No activity yet.</p>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, load_data(socket, @default_range)}
  end

  @impl true
  def handle_event("set_range", %{"days" => days}, socket) do
    {:noreply, load_data(socket, String.to_integer(days), socket.assigns[:filter_event_type])}
  end

  def handle_event("filter_activity", %{"event_type" => type}, socket) do
    filter = if type == "", do: nil, else: type
    {:noreply, load_data(socket, socket.assigns.range_days, filter)}
  end

  defp load_data(socket, range_days, filter_event_type \\ nil) do
    scope = socket.assigns.current_scope
    since = DateTime.add(DateTime.utc_now(:second), -range_days * 86_400, :second)

    stats = Audit.query_execution_stats(scope, since: since)
    active_users = Audit.most_active_users(scope, since: since)
    slowest = Audit.slowest_queries(scope, since: since, limit: 10)
    event_types = Audit.distinct_event_types(scope)

    event_opts =
      [since: since, limit: 20] ++
        if(filter_event_type, do: [event_type: filter_event_type], else: [])

    events = Audit.list_events(scope, event_opts)

    socket
    |> assign(
      range_days: range_days,
      stats: stats,
      active_users: active_users,
      slowest_queries: slowest,
      has_activity?: events != [],
      event_types: event_types,
      filter_event_type: filter_event_type
    )
    |> stream(:activity, events, reset: true)
  end

  defp success_rate(%{total_executions: 0}), do: 0

  defp success_rate(%{total_executions: total, successful: successful}) do
    round(successful / total * 100)
  end
end
