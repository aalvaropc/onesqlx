defmodule OnesqlxWeb.DashboardLive.Index do
  @moduledoc """
  LiveView for listing and creating dashboards.
  """

  use OnesqlxWeb, :live_view

  alias Onesqlx.Dashboards
  alias Onesqlx.Dashboards.Dashboard

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Dashboards
        <:subtitle>Visualize your data with charts and tables.</:subtitle>
        <:actions>
          <.button variant="primary" phx-click="open_new_modal">New Dashboard</.button>
        </:actions>
      </.header>

      <div
        id="dashboards"
        phx-update="stream"
        class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mt-6"
      >
        <div
          :for={{dom_id, dashboard} <- @streams.dashboards}
          id={dom_id}
          class="card border border-base-300 p-4"
        >
          <div class="flex items-start justify-between">
            <div class="flex-1 min-w-0">
              <h3 class="font-semibold truncate">{dashboard.title}</h3>
              <p :if={dashboard.description} class="text-sm text-base-content/60 truncate mt-1">
                {dashboard.description}
              </p>
            </div>
            <div class="flex items-center gap-2 ml-4 flex-shrink-0">
              <.link navigate={~p"/dashboards/#{dashboard.id}"} class="btn btn-sm btn-primary">
                View
              </.link>
              <button
                phx-click="delete"
                phx-value-id={dashboard.id}
                data-confirm="Are you sure you want to delete this dashboard?"
                class="btn btn-sm btn-ghost text-error"
              >
                <.icon name="hero-trash" class="size-4" />
              </button>
            </div>
          </div>
        </div>
      </div>

      <div :if={!@has_dashboards?} class="text-center py-12">
        <p class="text-base-content/60">No dashboards yet. Create one to get started.</p>
      </div>

      <div :if={@show_new_modal?} class="fixed inset-0 z-50 flex items-center justify-center">
        <div class="fixed inset-0 bg-black/50" phx-click="close_new_modal"></div>
        <div class="relative bg-base-100 rounded-lg p-6 w-full max-w-md shadow-xl">
          <h3 class="text-lg font-semibold mb-4">New Dashboard</h3>
          <.form
            for={@new_form}
            id="new-dashboard-form"
            phx-submit="create_dashboard"
            phx-change="validate_dashboard"
          >
            <.input field={@new_form[:title]} type="text" label="Title" required />
            <.input field={@new_form[:description]} type="textarea" label="Description (optional)" />
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
    dashboards = Dashboards.list_dashboards(scope)

    socket =
      socket
      |> assign(
        has_dashboards?: dashboards != [],
        show_new_modal?: false,
        new_form: nil
      )
      |> stream(:dashboards, dashboards)

    {:ok, socket}
  end

  @impl true
  def handle_event("open_new_modal", _params, socket) do
    changeset = Dashboards.change_dashboard(%Dashboard{})

    {:noreply,
     assign(socket, show_new_modal?: true, new_form: to_form(changeset, as: "dashboard"))}
  end

  def handle_event("close_new_modal", _params, socket) do
    {:noreply, assign(socket, show_new_modal?: false, new_form: nil)}
  end

  def handle_event("validate_dashboard", %{"dashboard" => params}, socket) do
    changeset =
      %Dashboard{}
      |> Dashboards.change_dashboard(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, new_form: to_form(changeset, as: "dashboard"))}
  end

  def handle_event("create_dashboard", %{"dashboard" => params}, socket) do
    scope = socket.assigns.current_scope

    case Dashboards.create_dashboard(scope, params) do
      {:ok, dashboard} ->
        socket =
          socket
          |> stream_insert(:dashboards, dashboard)
          |> assign(has_dashboards?: true, show_new_modal?: false, new_form: nil)

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, new_form: to_form(changeset, as: "dashboard"))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    dashboard = Dashboards.get_dashboard!(scope, id)
    {:ok, _} = Dashboards.delete_dashboard(scope, dashboard)

    dashboards_empty? = Dashboards.list_dashboards(scope) == []

    socket =
      socket
      |> stream_delete(:dashboards, dashboard)
      |> assign(has_dashboards?: !dashboards_empty?)

    {:noreply, socket}
  end
end
