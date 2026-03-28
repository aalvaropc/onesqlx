defmodule OnesqlxWeb.ScheduledQueryLive.Index do
  @moduledoc """
  LiveView for listing and creating scheduled queries.
  """

  use OnesqlxWeb, :live_view

  alias Onesqlx.SavedQueries
  alias Onesqlx.Scheduling
  alias Onesqlx.Scheduling.ScheduledQuery

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Scheduled Queries
        <:subtitle>Automate recurring query execution.</:subtitle>
        <:actions>
          <.button variant="primary" phx-click="open_new_modal">New Schedule</.button>
        </:actions>
      </.header>

      <div id="schedules" phx-update="stream" class="space-y-3 mt-6">
        <div
          :for={{dom_id, sq} <- @streams.schedules}
          id={dom_id}
          class="card border border-base-300 p-4"
        >
          <div class="flex items-start justify-between">
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <h3 class="font-semibold truncate">{sq.name}</h3>
                <span class={[
                  "badge badge-sm",
                  sq.enabled && "badge-success",
                  !sq.enabled && "badge-ghost"
                ]}>
                  {if sq.enabled, do: "Active", else: "Disabled"}
                </span>
                <span class="badge badge-sm badge-outline">{sq.schedule_type}</span>
              </div>
              <p :if={sq.saved_query} class="text-sm text-base-content/60 truncate mt-1">
                {sq.saved_query.title}
              </p>
              <div class="flex items-center gap-4 mt-2 text-xs text-base-content/50">
                <span :if={sq.last_run_at}>
                  Last run: {Calendar.strftime(sq.last_run_at, "%Y-%m-%d %H:%M")}
                </span>
                <span :if={sq.next_run_at && sq.enabled}>
                  Next run: {Calendar.strftime(sq.next_run_at, "%Y-%m-%d %H:%M")}
                </span>
              </div>
            </div>
            <div class="flex items-center gap-2 ml-4 flex-shrink-0">
              <button
                phx-click="toggle_enabled"
                phx-value-id={sq.id}
                class={["btn btn-sm btn-ghost", sq.enabled && "text-warning"]}
              >
                <.icon name={if sq.enabled, do: "hero-pause", else: "hero-play"} class="size-4" />
              </button>
              <.link navigate={~p"/schedules/#{sq.id}"} class="btn btn-sm btn-primary">
                View
              </.link>
              <button
                phx-click="delete"
                phx-value-id={sq.id}
                data-confirm="Are you sure you want to delete this schedule?"
                class="btn btn-sm btn-ghost text-error"
              >
                <.icon name="hero-trash" class="size-4" />
              </button>
            </div>
          </div>
        </div>
      </div>

      <div :if={!@has_schedules?} class="text-center py-12">
        <p class="text-base-content/60">
          No scheduled queries yet. Create one to automate your reports.
        </p>
      </div>

      <div :if={@show_new_modal?} class="fixed inset-0 z-50 flex items-center justify-center">
        <div class="fixed inset-0 bg-black/50" phx-click="close_new_modal"></div>
        <div class="relative bg-base-100 rounded-lg p-6 w-full max-w-md shadow-xl">
          <h3 class="text-lg font-semibold mb-4">New Schedule</h3>
          <.form
            for={@new_form}
            id="new-schedule-form"
            phx-submit="create_schedule"
            phx-change="validate_schedule"
          >
            <.input field={@new_form[:name]} type="text" label="Name" required />
            <div class="form-control mb-4">
              <label class="label"><span class="label-text">Saved Query</span></label>
              <select name="schedule[saved_query_id]" class="select select-bordered w-full" required>
                <option value="">Select a saved query...</option>
                <option :for={q <- @saved_queries} value={q.id}>{q.title}</option>
              </select>
            </div>
            <div class="form-control mb-4">
              <label class="label"><span class="label-text">Schedule Type</span></label>
              <select name="schedule[schedule_type]" class="select select-bordered w-full">
                <option value="hourly">Hourly</option>
                <option value="daily" selected>Daily</option>
                <option value="weekly">Weekly</option>
                <option value="cron">Custom (Cron)</option>
              </select>
            </div>
            <.input
              :if={@show_cron_field?}
              field={@new_form[:cron_expression]}
              type="text"
              label="Cron Expression"
              placeholder="*/5 * * * *"
            />
            <.input field={@new_form[:notify_email]} type="email" label="Notify Email (optional)" />
            <div class="flex justify-end gap-2 mt-4">
              <button type="button" phx-click="close_new_modal" class="btn btn-sm">Cancel</button>
              <.button variant="primary" phx-disable-with="Creating...">Create</.button>
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
    schedules = Scheduling.list_scheduled_queries(scope)

    socket =
      socket
      |> assign(
        has_schedules?: schedules != [],
        show_new_modal?: false,
        show_cron_field?: false,
        new_form: nil,
        saved_queries: []
      )
      |> stream(:schedules, schedules)

    {:ok, socket}
  end

  @impl true
  def handle_event("open_new_modal", _params, socket) do
    scope = socket.assigns.current_scope
    saved_queries = SavedQueries.list_saved_queries(scope)
    changeset = Scheduling.change_scheduled_query(%ScheduledQuery{})

    socket =
      assign(socket,
        show_new_modal?: true,
        show_cron_field?: false,
        new_form: to_form(changeset, as: "schedule"),
        saved_queries: saved_queries
      )

    {:noreply, socket}
  end

  def handle_event("close_new_modal", _params, socket) do
    {:noreply, assign(socket, show_new_modal?: false, new_form: nil)}
  end

  def handle_event("validate_schedule", %{"schedule" => params}, socket) do
    show_cron = params["schedule_type"] == "cron"

    changeset =
      %ScheduledQuery{}
      |> Scheduling.change_scheduled_query(params)
      |> Map.put(:action, :validate)

    {:noreply,
     assign(socket, new_form: to_form(changeset, as: "schedule"), show_cron_field?: show_cron)}
  end

  def handle_event("create_schedule", %{"schedule" => params}, socket) do
    scope = socket.assigns.current_scope

    case Scheduling.create_scheduled_query(scope, params) do
      {:ok, sq} ->
        sq = Onesqlx.Repo.preload(sq, :saved_query)

        socket =
          socket
          |> stream_insert(:schedules, sq)
          |> assign(has_schedules?: true, show_new_modal?: false, new_form: nil)

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, new_form: to_form(changeset, as: "schedule"))}
    end
  end

  def handle_event("toggle_enabled", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    sq = Scheduling.get_scheduled_query!(scope, id)
    {:ok, updated} = Scheduling.toggle_enabled(scope, sq)
    updated = Onesqlx.Repo.preload(updated, :saved_query)
    {:noreply, stream_insert(socket, :schedules, updated)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    sq = Scheduling.get_scheduled_query!(scope, id)
    {:ok, _} = Scheduling.delete_scheduled_query(scope, sq)

    schedules_empty? = Scheduling.list_scheduled_queries(scope) == []

    socket =
      socket
      |> stream_delete(:schedules, sq)
      |> assign(has_schedules?: !schedules_empty?)

    {:noreply, socket}
  end
end
