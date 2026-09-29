defmodule Onesqlx.Workspaces do
  @moduledoc """
  The Workspaces context.

  Manages workspaces, memberships, and roles. A workspace is the top-level
  organizational unit where teams collaborate on data sources, queries,
  and dashboards.
  """

  import Ecto.Query, warn: false
  alias Onesqlx.Repo

  alias Onesqlx.Accounts.User
  alias Onesqlx.Workspaces.{Workspace, WorkspaceInvitation, WorkspaceMember}

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

  def update_workspace(%Workspace{} = workspace, attrs) do
    workspace
    |> Workspace.changeset(attrs)
    |> Repo.update()
  end

  def remove_member(%Workspace{} = workspace, %WorkspaceMember{} = member) do
    if member.role == "owner" && owner_count(workspace) <= 1 do
      {:error, :last_owner}
    else
      Repo.delete(member)
    end
  end

  def update_member_role(%WorkspaceMember{} = member, new_role) do
    member
    |> WorkspaceMember.changeset(%{role: new_role})
    |> Repo.update()
  end

  defp owner_count(workspace) do
    WorkspaceMember
    |> where(workspace_id: ^workspace.id, role: "owner")
    |> Repo.aggregate(:count)
  end

  ## Invitations

  @doc """
  Invites `email` to the scope's workspace with `role`.

  Only owners and admins can invite. Returns `{:ok, invitation, raw_token}`
  on success — the raw token is only available here and must be emailed
  immediately.
  """
  def invite_member(scope, email, role) do
    cond do
      scope.role not in ["owner", "admin"] ->
        {:error, :unauthorized}

      already_member?(scope.workspace, email) ->
        {:error, :already_member}

      true ->
        {raw, changeset} =
          WorkspaceInvitation.build(scope.workspace, scope.user, %{
            "email" => email,
            "role" => role
          })

        case Repo.insert(changeset) do
          {:ok, invitation} -> {:ok, invitation, raw}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  defp already_member?(workspace, email) do
    WorkspaceMember
    |> join(:inner, [wm], u in User, on: u.id == wm.user_id)
    |> where([wm, u], wm.workspace_id == ^workspace.id and u.email == ^email)
    |> Repo.exists?()
  end

  def list_pending_invitations(workspace) do
    now = DateTime.utc_now(:second)

    WorkspaceInvitation
    |> where([i], i.workspace_id == ^workspace.id)
    |> where([i], is_nil(i.accepted_at) and i.expires_at > ^now)
    |> order_by([i], desc: i.inserted_at)
    |> Repo.all()
  end

  @doc """
  Revokes a pending invitation. Only owners and admins of the scope's
  workspace can revoke, and only invitations belonging to that workspace.
  """
  def revoke_invitation(scope, invitation_id) do
    if scope.role in ["owner", "admin"] do
      case Repo.get_by(WorkspaceInvitation,
             id: invitation_id,
             workspace_id: scope.workspace.id
           ) do
        nil -> {:error, :not_found}
        invitation -> Repo.delete(invitation)
      end
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Accepts an invitation by its raw token on behalf of `user`.

  The token must hash to a pending, unexpired invitation whose email
  matches the user's email (citext makes the comparison case-insensitive).
  Adds the user as a member with the invited role and marks the invitation
  accepted. If the user somehow already joined, the invitation is simply
  marked accepted (idempotent).
  """
  def accept_invitation(user, raw_token) when is_binary(raw_token) do
    token_hash = WorkspaceInvitation.hash_token(raw_token)
    now = DateTime.utc_now(:second)

    invitation =
      WorkspaceInvitation
      |> where([i], i.token_hash == ^token_hash)
      |> where([i], is_nil(i.accepted_at) and i.expires_at > ^now)
      |> preload(:workspace)
      |> Repo.one()

    cond do
      is_nil(invitation) ->
        {:error, :invalid}

      not same_email?(invitation.email, user.email) ->
        {:error, :wrong_account}

      true ->
        do_accept(invitation, user, now)
    end
  end

  defp do_accept(invitation, user, now) do
    Repo.transact(fn ->
      with {:ok, _member} <- ensure_membership(invitation, user),
           {:ok, _} <-
             invitation
             |> Ecto.Changeset.change(accepted_at: now)
             |> Repo.update() do
        {:ok, invitation.workspace}
      end
    end)
  end

  defp same_email?(invited, actual) do
    String.downcase(invited) == String.downcase(actual)
  end

  defp ensure_membership(invitation, user) do
    if member?(invitation.workspace, user) do
      {:ok, :already_member}
    else
      add_member(invitation.workspace, user, invitation.role)
    end
  end

  @doc """
  Resolves a workspace for building a scope.

  If `workspace_id` is given and the user is a member, returns that workspace.
  Otherwise returns the user's first workspace (by membership inserted_at).
  """
  def get_workspace_for_scope(user, workspace_id \\ nil)

  def get_workspace_for_scope(user, workspace_id) when is_binary(workspace_id) do
    Workspace
    |> join(:inner, [w], wm in WorkspaceMember,
      on: wm.workspace_id == w.id and wm.user_id == ^user.id
    )
    |> where([w, _wm], w.id == ^workspace_id)
    |> Repo.one()
    |> case do
      nil -> get_workspace_for_scope(user, nil)
      workspace -> workspace
    end
  end

  def get_workspace_for_scope(user, _) do
    Workspace
    |> join(:inner, [w], wm in WorkspaceMember,
      on: wm.workspace_id == w.id and wm.user_id == ^user.id
    )
    |> order_by([_w, wm], asc: wm.inserted_at)
    |> limit(1)
    |> Repo.one()
  end
end
