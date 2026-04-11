defmodule OnesqlxWeb.AuditLive do
  @moduledoc """
  LiveView for viewing and filtering audit events with CSV export.
  """

  use OnesqlxWeb, :live_view

  alias Onesqlx.Audit

  @page_size 50

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Audit Log
        <:subtitle>View and export workspace activity for compliance.</:subtitle>
      </.header>

      <div class="flex flex-wrap items-end gap-4 mt-6 mb-4">
        <form phx-change="filter" class="flex flex-wrap items-end gap-4">
          <div class="form-control">
            <label class="label"><span class="label-text text-xs">Event Type</span></label>
            <select name="event_type" class="select select-bordered select-sm w-48">
              <option value="">All types</option>
              <option :for={t <- @event_types} value={t} selected={@filter_event_type == t}>
                {t}
              </option>
            </select>
          </div>
          <div class="form-control">
            <label class="label"><span class="label-text text-xs">Since</span></label>
            <input
              type="date"
              name="since"
              value={@filter_since}
              class="input input-bordered input-sm w-40"
            />
          </div>
        </form>

        <form action={~p"/exports/audit-csv"} method="post" class="ml-auto">
          <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
          <input type="hidden" name="event_type" value={@filter_event_type || ""} />
          <input type="hidden" name="since" value={@filter_since || ""} />
          <button type="submit" class="btn btn-sm">
            <.icon name="hero-arrow-down-tray" class="size-4" /> Export CSV
          </button>
        </form>
      </div>

      <div class="text-xs text-base-content/50 mb-2">
        {@total} events
      </div>

      <div class="overflow-x-auto">
        <table class="table table-xs">
          <thead>
            <tr>
              <th>Timestamp</th>
              <th>User</th>
              <th>Event</th>
              <th>Resource</th>
              <th>Details</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={{dom_id, event} <- @streams.events} id={dom_id}>
              <td class="text-xs font-mono whitespace-nowrap">
                {Calendar.strftime(event.occurred_at, "%Y-%m-%d %H:%M:%S")}
              </td>
              <td class="text-xs">
                {(event.user && event.user.email) || "system"}
              </td>
              <td>
                <span class="badge badge-xs badge-outline">{event.event_type}</span>
              </td>
              <td class="text-xs">
                <span :if={event.resource_type} class="font-mono">
                  {event.resource_type}
                </span>
              </td>
              <td class="text-xs max-w-xs truncate">
                {if event.metadata && event.metadata != %{},
                  do: Jason.encode!(event.metadata),
                  else: ""}
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div :if={@total == 0} class="text-center py-12">
        <p class="text-base-content/60">No audit events found.</p>
      </div>

      <div :if={@total > 0} class="flex justify-center gap-2 mt-4">
        <button
          :if={@page > 0}
          phx-click="prev_page"
          class="btn btn-sm"
        >
          Previous
        </button>
        <span class="text-sm text-base-content/60 self-center">
          Page {@page + 1} of {ceil(@total / @page_size)}
        </span>
        <button
          :if={(@page + 1) * @page_size < @total}
          phx-click="next_page"
          class="btn btn-sm"
        >
          Next
        </button>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    event_types = Audit.distinct_event_types(scope)

    socket =
      socket
      |> assign(
        event_types: event_types,
        filter_event_type: nil,
        filter_since: nil,
        page: 0,
        page_size: @page_size,
        total: 0
      )
      |> load_events()

    {:ok, socket}
  end

  @impl true
  def handle_event("filter", params, socket) do
    event_type = if params["event_type"] == "", do: nil, else: params["event_type"]
    since = if params["since"] == "", do: nil, else: params["since"]

    socket =
      socket
      |> assign(filter_event_type: event_type, filter_since: since, page: 0)
      |> load_events()

    {:noreply, socket}
  end

  def handle_event("prev_page", _params, socket) do
    socket =
      socket
      |> update(:page, &max(&1 - 1, 0))
      |> load_events()

    {:noreply, socket}
  end

  def handle_event("next_page", _params, socket) do
    socket =
      socket
      |> update(:page, &(&1 + 1))
      |> load_events()

    {:noreply, socket}
  end

  defp load_events(socket) do
    scope = socket.assigns.current_scope
    opts = build_filter_opts(socket.assigns)

    events =
      Audit.list_events(
        scope,
        opts ++ [limit: @page_size, offset: socket.assigns.page * @page_size]
      )

    total = Audit.count_events(scope, opts)

    socket
    |> assign(total: total)
    |> stream(:events, events, reset: true)
  end

  defp build_filter_opts(assigns) do
    opts = []

    opts =
      if assigns.filter_event_type,
        do: [{:event_type, assigns.filter_event_type} | opts],
        else: opts

    if assigns.filter_since do
      case Date.from_iso8601(assigns.filter_since) do
        {:ok, date} -> [{:since, DateTime.new!(date, ~T[00:00:00], "Etc/UTC")} | opts]
        _ -> opts
      end
    else
      opts
    end
  end
end
