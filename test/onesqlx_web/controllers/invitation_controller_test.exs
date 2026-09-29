defmodule OnesqlxWeb.InvitationControllerTest do
  use OnesqlxWeb.ConnCase, async: true

  import Onesqlx.AccountsFixtures

  alias Onesqlx.Workspaces

  defp owner_scope do
    %{user_scope_fixture() | role: "owner"}
  end

  describe "GET /invitations/:token" do
    test "accepts the invitation and switches the session workspace", %{conn: conn} do
      scope = owner_scope()
      invitee = user_fixture()
      {:ok, _, raw} = Workspaces.invite_member(scope, invitee.email, "member")

      conn = conn |> log_in_user(invitee) |> get(~p"/invitations/#{raw}")

      assert redirected_to(conn) == ~p"/dashboards"
      assert get_session(conn, :workspace_id) == scope.workspace.id
      assert Workspaces.get_member_role(scope.workspace, invitee) == "member"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Welcome to #{scope.workspace.name}"
    end

    test "rejects a token sent to a different email", %{conn: conn} do
      scope = owner_scope()
      stranger = user_fixture()
      {:ok, _, raw} = Workspaces.invite_member(scope, "invited@example.com", "member")

      conn = conn |> log_in_user(stranger) |> get(~p"/invitations/#{raw}")

      assert redirected_to(conn) == ~p"/dashboards"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "different email"
      refute Workspaces.member?(scope.workspace, stranger)
    end

    test "shows an error for an invalid token", %{conn: conn} do
      invitee = user_fixture()

      conn = conn |> log_in_user(invitee) |> get(~p"/invitations/bogus-token")

      assert redirected_to(conn) == ~p"/dashboards"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "invalid or has expired"
    end

    test "redirects unauthenticated users to log in", %{conn: conn} do
      conn = get(conn, ~p"/invitations/some-token")

      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end
end
