defmodule Onesqlx.WorkspacesInvitationsTest do
  use Onesqlx.DataCase, async: true

  import Onesqlx.AccountsFixtures

  alias Onesqlx.Repo
  alias Onesqlx.Workspaces
  alias Onesqlx.Workspaces.WorkspaceInvitation

  defp owner_scope do
    %{user_scope_fixture() | role: "owner"}
  end

  describe "invite_member/3" do
    test "owner can invite and receives the raw token" do
      scope = owner_scope()

      assert {:ok, invitation, raw} =
               Workspaces.invite_member(scope, "newbie@example.com", "member")

      assert invitation.email == "newbie@example.com"
      assert invitation.role == "member"
      assert invitation.workspace_id == scope.workspace.id
      assert invitation.invited_by_id == scope.user.id
      assert invitation.token_hash == :crypto.hash(:sha256, raw)
      assert is_nil(invitation.accepted_at)
      assert DateTime.after?(invitation.expires_at, DateTime.utc_now())
    end

    test "admin can invite" do
      scope = %{owner_scope() | role: "admin"}
      assert {:ok, _invitation, _raw} = Workspaces.invite_member(scope, "a@example.com", "viewer")
    end

    test "member and viewer cannot invite" do
      for role <- ["member", "viewer"] do
        scope = %{owner_scope() | role: role}

        assert {:error, :unauthorized} =
                 Workspaces.invite_member(scope, "x@example.com", "member")
      end
    end

    test "rejects inviting an existing member (case-insensitive email)" do
      scope = owner_scope()

      assert {:error, :already_member} =
               Workspaces.invite_member(scope, String.upcase(scope.user.email), "member")
    end

    test "rejects invalid emails and non-invitable roles" do
      scope = owner_scope()

      assert {:error, changeset} = Workspaces.invite_member(scope, "not-an-email", "member")
      assert %{email: [_ | _]} = errors_on(changeset)

      assert {:error, changeset} = Workspaces.invite_member(scope, "ok@example.com", "owner")
      assert %{role: [_ | _]} = errors_on(changeset)
    end

    test "rejects a duplicate pending invitation for the same email" do
      scope = owner_scope()

      assert {:ok, _, _} = Workspaces.invite_member(scope, "dup@example.com", "member")
      assert {:error, changeset} = Workspaces.invite_member(scope, "dup@example.com", "viewer")
      assert %{email: ["already has a pending invitation"]} = errors_on(changeset)
    end
  end

  describe "list_pending_invitations/1" do
    test "returns only pending, unexpired invitations for the workspace" do
      scope = owner_scope()
      other_scope = owner_scope()

      {:ok, pending, _} = Workspaces.invite_member(scope, "pending@example.com", "member")
      {:ok, expired, _} = Workspaces.invite_member(scope, "expired@example.com", "member")
      {:ok, accepted, _} = Workspaces.invite_member(scope, "accepted@example.com", "member")
      {:ok, _other, _} = Workspaces.invite_member(other_scope, "other@example.com", "member")

      past = DateTime.add(DateTime.utc_now(:second), -1, :day)

      expired |> Ecto.Changeset.change(expires_at: past) |> Repo.update!()

      accepted
      |> Ecto.Changeset.change(accepted_at: DateTime.utc_now(:second))
      |> Repo.update!()

      assert [%WorkspaceInvitation{id: id}] =
               Workspaces.list_pending_invitations(scope.workspace)

      assert id == pending.id
    end
  end

  describe "revoke_invitation/2" do
    test "owner can revoke a workspace invitation" do
      scope = owner_scope()
      {:ok, invitation, _} = Workspaces.invite_member(scope, "bye@example.com", "member")

      assert {:ok, _} = Workspaces.revoke_invitation(scope, invitation.id)
      assert Workspaces.list_pending_invitations(scope.workspace) == []
    end

    test "cannot revoke another workspace's invitation" do
      scope = owner_scope()
      other_scope = owner_scope()
      {:ok, invitation, _} = Workspaces.invite_member(other_scope, "x@example.com", "member")

      assert {:error, :not_found} = Workspaces.revoke_invitation(scope, invitation.id)
    end

    test "non-admins cannot revoke" do
      scope = owner_scope()
      {:ok, invitation, _} = Workspaces.invite_member(scope, "x@example.com", "member")

      viewer_scope = %{scope | role: "viewer"}
      assert {:error, :unauthorized} = Workspaces.revoke_invitation(viewer_scope, invitation.id)
    end
  end

  describe "accept_invitation/2" do
    test "adds the invited user with the invited role and marks acceptance" do
      scope = owner_scope()
      invitee = user_fixture()

      {:ok, invitation, raw} = Workspaces.invite_member(scope, invitee.email, "viewer")

      assert {:ok, workspace} = Workspaces.accept_invitation(invitee, raw)
      assert workspace.id == scope.workspace.id
      assert Workspaces.get_member_role(scope.workspace, invitee) == "viewer"
      assert %{accepted_at: %DateTime{}} = Repo.reload(invitation)
    end

    test "email comparison is case-insensitive" do
      scope = owner_scope()
      invitee = user_fixture()

      {:ok, _, raw} = Workspaces.invite_member(scope, String.upcase(invitee.email), "member")

      assert {:ok, _workspace} = Workspaces.accept_invitation(invitee, raw)
    end

    test "rejects a user logged in with a different email" do
      scope = owner_scope()
      stranger = user_fixture()

      {:ok, _, raw} = Workspaces.invite_member(scope, "someone-else@example.com", "member")

      assert {:error, :wrong_account} = Workspaces.accept_invitation(stranger, raw)
      refute Workspaces.member?(scope.workspace, stranger)
    end

    test "rejects invalid, expired, and already-accepted tokens" do
      scope = owner_scope()
      invitee = user_fixture()

      assert {:error, :invalid} = Workspaces.accept_invitation(invitee, "garbage-token")

      {:ok, expired, raw_expired} = Workspaces.invite_member(scope, invitee.email, "member")
      past = DateTime.add(DateTime.utc_now(:second), -1, :day)
      expired |> Ecto.Changeset.change(expires_at: past) |> Repo.update!()

      assert {:error, :invalid} = Workspaces.accept_invitation(invitee, raw_expired)

      expired |> Ecto.Changeset.change(expires_at: invitation_future()) |> Repo.update!()
      assert {:ok, _} = Workspaces.accept_invitation(invitee, raw_expired)
      assert {:error, :invalid} = Workspaces.accept_invitation(invitee, raw_expired)
    end

    test "is idempotent when the user is already a member" do
      scope = owner_scope()
      invitee = user_fixture()

      {:ok, _, raw} = Workspaces.invite_member(scope, invitee.email, "viewer")
      {:ok, _} = Workspaces.add_member(scope.workspace, invitee, "member")

      assert {:ok, _workspace} = Workspaces.accept_invitation(invitee, raw)
      # existing role is preserved, invitation cannot grant a different one
      assert Workspaces.get_member_role(scope.workspace, invitee) == "member"
    end
  end

  defp invitation_future do
    DateTime.add(DateTime.utc_now(:second), 3, :day)
  end
end
