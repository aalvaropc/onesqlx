defmodule OnesqlxWeb.WorkspaceLive.Settings do
  @moduledoc """
  LiveView for workspace settings and member management.
  """

  use OnesqlxWeb, :live_view

  alias Onesqlx.Workspaces

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Workspace Settings
        <:subtitle>{@workspace.name}</:subtitle>
      </.header>

      <%!-- Rename section --%>
      <div :if={@role in ["owner", "admin"]} class="card border border-base-300 p-4 mt-6">
        <h3 class="font-semibold mb-3">Workspace Name</h3>
        <.form for={@name_form} id="rename-form" phx-submit="rename" class="flex items-end gap-3">
          <div class="flex-1">
            <.input field={@name_form[:name]} type="text" label="Name" />
          </div>
          <.button variant="primary" phx-disable-with="Saving...">Save</.button>
        </.form>
      </div>

      <%!-- Members section --%>
      <div class="card border border-base-300 p-4 mt-6">
        <h3 class="font-semibold mb-3">Members</h3>
        <div class="space-y-3">
          <div
            :for={member <- @members}
            class="flex items-center justify-between py-2 border-b border-base-200 last:border-0"
          >
            <div>
              <span class="font-medium">{member.user.email}</span>
              <span class={[
                "badge badge-sm ml-2",
                member.role == "owner" && "badge-primary",
                member.role == "admin" && "badge-secondary",
                member.role == "member" && "badge-ghost"
              ]}>
                {member.role}
              </span>
            </div>
            <button
              :if={@role in ["owner", "admin"] && member.user.id != @current_scope.user.id}
              phx-click="remove_member"
              phx-value-id={member.id}
              data-confirm="Remove this member from the workspace?"
              class="btn btn-xs btn-ghost text-error"
            >
              Remove
            </button>
          </div>
        </div>
      </div>

      <%!-- Danger zone --%>
      <div :if={@role == "owner"} class="card border border-error/30 p-4 mt-6">
        <h3 class="font-semibold text-error mb-3">Danger Zone</h3>
        <p class="text-sm text-base-content/60 mb-3">
          Deleting a workspace permanently removes all data sources, queries, dashboards, and schedules.
        </p>
        <button
          phx-click="delete_workspace"
          data-confirm="Are you absolutely sure? This cannot be undone."
          class="btn btn-sm btn-error"
        >
          Delete Workspace
        </button>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    workspace = scope.workspace
    role = Workspaces.get_member_role(workspace, scope.user)
    members = Workspaces.list_members(workspace)
    changeset = Workspaces.change_workspace(workspace)

    socket =
      assign(socket,
        workspace: workspace,
        role: role,
        members: members,
        name_form: to_form(changeset, as: "workspace")
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("rename", %{"workspace" => params}, socket) do
    workspace = socket.assigns.workspace

    case Workspaces.update_workspace(workspace, params) do
      {:ok, updated} ->
        changeset = Workspaces.change_workspace(updated)

        {:noreply,
         socket
         |> assign(workspace: updated, name_form: to_form(changeset, as: "workspace"))
         |> put_flash(:info, "Workspace renamed.")}

      {:error, changeset} ->
        {:noreply, assign(socket, name_form: to_form(changeset, as: "workspace"))}
    end
  end

  def handle_event("remove_member", %{"id" => member_id}, socket) do
    workspace = socket.assigns.workspace
    member = Enum.find(socket.assigns.members, &(&1.id == member_id))

    case member && Workspaces.remove_member(workspace, member) do
      {:ok, _} ->
        members = Workspaces.list_members(workspace)
        {:noreply, assign(socket, members: members) |> put_flash(:info, "Member removed.")}

      {:error, :last_owner} ->
        {:noreply, put_flash(socket, :error, "Cannot remove the last owner.")}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("delete_workspace", _params, socket) do
    workspace = socket.assigns.workspace

    case Onesqlx.Repo.delete(workspace) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Workspace deleted.")
         |> redirect(to: ~p"/dashboards")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete workspace.")}
    end
  end
end
