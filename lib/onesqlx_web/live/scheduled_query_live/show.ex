defmodule OnesqlxWeb.ScheduledQueryLive.Show do
  @moduledoc """
  LiveView for viewing a scheduled query's details and run history.
  """

  use OnesqlxWeb, :live_view

  alias Onesqlx.Scheduling
  alias Onesqlx.Scheduling.ExecuteWorker

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex items-center gap-4 mb-6">
        <.link navigate={~p"/schedules"} class="btn btn-sm btn-ghost">
          <.icon name="hero-arrow-left" class="size-4" /> Back
        </.link>
        <h1 class="text-2xl font-bold flex-1">{@scheduled_query.name}</h1>
        <button phx-click="open_edit_modal" class="btn btn-sm btn-ghost">
          <.icon name="hero-pencil-square" class="size-4" /> Edit
        </button>
        <button phx-click="run_now" class="btn btn-sm btn-primary">
          <.icon name="hero-play" class="size-4" /> Run Now
        </button>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
        <div class="card border border-base-300 p-4">
          <h3 class="font-semibold mb-3">Schedule Details</h3>
          <dl class="space-y-2 text-sm">
            <div class="flex justify-between">
              <dt class="text-base-content/60">Saved Query</dt>
              <dd>{(@scheduled_query.saved_query && @scheduled_query.saved_query.title) || "—"}</dd>
            </div>
            <div class="flex justify-between">
              <dt class="text-base-content/60">Type</dt>
              <dd class="badge badge-sm badge-outline">{@scheduled_query.schedule_type}</dd>
            </div>
            <div :if={@scheduled_query.cron_expression} class="flex justify-between">
              <dt class="text-base-content/60">Cron</dt>
              <dd class="font-mono">{@scheduled_query.cron_expression}</dd>
            </div>
            <div class="flex justify-between">
              <dt class="text-base-content/60">Status</dt>
              <dd>
                <span class={[
                  "badge badge-sm",
                  @scheduled_query.enabled && "badge-success",
                  !@scheduled_query.enabled && "badge-ghost"
                ]}>
                  {if @scheduled_query.enabled, do: "Active", else: "Disabled"}
                </span>
              </dd>
            </div>
            <div :if={@scheduled_query.notify_email} class="flex justify-between">
              <dt class="text-base-content/60">Notify</dt>
              <dd>{@scheduled_query.notify_email}</dd>
            </div>
            <div :if={@scheduled_query.webhook_url} class="flex justify-between">
              <dt class="text-base-content/60">Webhook</dt>
              <dd class="truncate max-w-48">{@scheduled_query.webhook_url}</dd>
            </div>
            <div :if={@scheduled_query.last_run_at} class="flex justify-between">
              <dt class="text-base-content/60">Last Run</dt>
              <dd>{Calendar.strftime(@scheduled_query.last_run_at, "%Y-%m-%d %H:%M")}</dd>
            </div>
            <div :if={@scheduled_query.next_run_at} class="flex justify-between">
              <dt class="text-base-content/60">Next Run</dt>
              <dd>{Calendar.strftime(@scheduled_query.next_run_at, "%Y-%m-%d %H:%M")}</dd>
            </div>
          </dl>
        </div>
      </div>

      <h2 class="text-lg font-semibold mb-4">Run History</h2>

      <div id="runs" phx-update="stream" class="space-y-2">
        <div
          :for={{dom_id, run} <- @streams.runs}
          id={dom_id}
          class="card border border-base-300 p-3"
        >
          <div class="flex items-center gap-3">
            <span class={[
              "badge badge-sm",
              run.status == "success" && "badge-success",
              run.status == "error" && "badge-error",
              run.status == "timeout" && "badge-warning",
              run.status == "running" && "badge-info"
            ]}>
              {run.status}
            </span>
            <span class="text-sm text-base-content/60">
              {Calendar.strftime(run.started_at, "%Y-%m-%d %H:%M:%S")}
            </span>
            <span :if={run.duration_ms} class="text-sm text-base-content/50">
              {run.duration_ms}ms
            </span>
            <span :if={run.row_count} class="text-sm text-base-content/50">
              {run.row_count} rows
            </span>
            <span :if={run.error_message} class="text-sm text-error truncate flex-1">
              {run.error_message}
            </span>
          </div>
        </div>
      </div>

      <div :if={!@has_runs?} class="text-center py-8">
        <p class="text-base-content/60">No runs yet. Click "Run Now" to execute manually.</p>
      </div>

      <div
        :if={@show_edit_modal?}
        role="dialog"
        aria-modal="true"
        class="fixed inset-0 z-50 flex items-center justify-center"
      >
        <div class="fixed inset-0 bg-black/50" phx-click="close_edit_modal"></div>
        <div class="relative bg-base-100 rounded-lg p-6 w-full max-w-md shadow-xl">
          <h3 class="text-lg font-semibold mb-4">Edit Schedule</h3>
          <.form
            for={@edit_form}
            id="edit-schedule-form"
            phx-submit="update_schedule"
            phx-change="validate_edit"
          >
            <.input field={@edit_form[:name]} type="text" label="Name" required />
            <div class="form-control mb-4">
              <label class="label"><span class="label-text">Schedule Type</span></label>
              <select name="schedule[schedule_type]" class="select select-bordered w-full">
                <option value="hourly" selected={@edit_form[:schedule_type].value == "hourly"}>
                  Hourly
                </option>
                <option value="daily" selected={@edit_form[:schedule_type].value == "daily"}>
                  Daily
                </option>
                <option value="weekly" selected={@edit_form[:schedule_type].value == "weekly"}>
                  Weekly
                </option>
                <option value="cron" selected={@edit_form[:schedule_type].value == "cron"}>
                  Custom (Cron)
                </option>
              </select>
            </div>
            <.input
              :if={@show_cron_field?}
              field={@edit_form[:cron_expression]}
              type="text"
              label="Cron Expression"
              placeholder="*/5 * * * *"
            />
            <.input
              field={@edit_form[:notify_email]}
              type="email"
              label="Notify Email (optional)"
            />
            <.input
              field={@edit_form[:webhook_url]}
              type="url"
              label="Webhook URL (optional)"
              placeholder="https://hooks.slack.com/..."
            />
            <div class="flex justify-end gap-2 mt-4">
              <button type="button" phx-click="close_edit_modal" class="btn btn-sm">Cancel</button>
              <.button variant="primary" phx-disable-with="Saving...">Save</.button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    scope = socket.assigns.current_scope
    sq = Scheduling.get_scheduled_query!(scope, id)
    runs = Scheduling.list_runs(scope, sq.id)

    socket =
      socket
      |> assign(
        scheduled_query: sq,
        has_runs?: runs != [],
        show_edit_modal?: false,
        show_cron_field?: sq.schedule_type == "cron",
        edit_form: nil
      )
      |> stream(:runs, runs)

    {:ok, socket}
  end

  @impl true
  def handle_event("run_now", _params, socket) do
    sq = socket.assigns.scheduled_query
    {:ok, _job} = ExecuteWorker.enqueue(sq.id)

    {:noreply, put_flash(socket, :info, "Execution queued. Refresh to see results.")}
  end

  def handle_event("open_edit_modal", _params, socket) do
    sq = socket.assigns.scheduled_query
    changeset = Scheduling.change_scheduled_query(sq)

    {:noreply,
     assign(socket,
       show_edit_modal?: true,
       show_cron_field?: sq.schedule_type == "cron",
       edit_form: to_form(changeset, as: "schedule")
     )}
  end

  def handle_event("close_edit_modal", _params, socket) do
    {:noreply, assign(socket, show_edit_modal?: false, edit_form: nil)}
  end

  def handle_event("validate_edit", %{"schedule" => params}, socket) do
    show_cron = params["schedule_type"] == "cron"

    changeset =
      socket.assigns.scheduled_query
      |> Scheduling.change_scheduled_query(params)
      |> Map.put(:action, :validate)

    {:noreply,
     assign(socket, edit_form: to_form(changeset, as: "schedule"), show_cron_field?: show_cron)}
  end

  def handle_event("update_schedule", %{"schedule" => params}, socket) do
    scope = socket.assigns.current_scope
    sq = socket.assigns.scheduled_query

    case Scheduling.update_scheduled_query(scope, sq, params) do
      {:ok, updated} ->
        updated = Scheduling.get_scheduled_query!(scope, updated.id)

        {:noreply,
         socket
         |> assign(scheduled_query: updated, show_edit_modal?: false, edit_form: nil)
         |> put_flash(:info, "Schedule updated.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, edit_form: to_form(changeset, as: "schedule"))}
    end
  end
end
