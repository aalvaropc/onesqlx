defmodule Onesqlx.Workspaces do
  @moduledoc """
  The Workspaces context.

  Manages workspaces, memberships, and roles. A workspace is the top-level
  organizational unit where teams collaborate on data sources, queries,
  and dashboards.
  """

  import Ecto.Query, warn: false
  alias Onesqlx.Repo

  alias Onesqlx.Workspaces.{Workspace, WorkspaceMember}

  def create_workspace(attrs) do
    %Workspace{}
    |> Workspace.changeset(attrs)
    |> Repo.insert()
  end

  def get_workspace!(id), do: Repo.get!(Workspace, id)

  def list_workspaces_for_user(user) do
    Workspace
    |> join(:inner, [w], wm in assoc(w, :workspace_members))
    |> where([_w, wm], wm.user_id == ^user.id)
    |> Repo.all()
  end

  def change_workspace(workspace, attrs \\ %{}) do
    Workspace.changeset(workspace, attrs)
  end

  def create_workspace_with_owner(user, attrs) do
    slug_suffix = String.slice(user.id, 0, 8)

    Repo.transact(fn ->
      with {:ok, workspace} <-
             %Workspace{}
             |> Workspace.changeset(attrs)
             |> maybe_append_slug_suffix(slug_suffix)
             |> Repo.insert(),
           {:ok, _member} <- add_member(workspace, user, "owner") do
        {:ok, workspace}
      end
    end)
  end

  defp maybe_append_slug_suffix(changeset, suffix) do
    case Ecto.Changeset.get_change(changeset, :slug) do
      nil -> changeset
      slug -> Ecto.Changeset.put_change(changeset, :slug, "#{slug}-#{suffix}")
    end
  end

  def add_member(workspace, user, role \\ "member") do
    %WorkspaceMember{}
    |> WorkspaceMember.changeset(%{
      workspace_id: workspace.id,
      user_id: user.id,
      role: role
    })
    |> Repo.insert()
  end

  def list_members(workspace) do
    WorkspaceMember
    |> where([wm], wm.workspace_id == ^workspace.id)
    |> preload(:user)
    |> Repo.all()
  end

  def get_member_role(workspace, user) do
    WorkspaceMember
    |> where([wm], wm.workspace_id == ^workspace.id and wm.user_id == ^user.id)
    |> select([wm], wm.role)
    |> Repo.one()
  end

  def member?(workspace, user) do
    get_member_role(workspace, user) != nil
  end
end
