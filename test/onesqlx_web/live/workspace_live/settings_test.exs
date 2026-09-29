defmodule OnesqlxWeb.WorkspaceLive.SettingsTest do
  use OnesqlxWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "Settings" do
    test "renders workspace name", %{conn: conn, scope: scope} do
      {:ok, _lv, html} = live(conn, ~p"/workspace/settings")
      assert html =~ scope.workspace.name
    end

    test "owner can rename workspace", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/workspace/settings")

      lv
      |> form("#rename-form", workspace: %{name: "New Name"})
      |> render_submit()

      assert has_element?(lv, "#rename-form")
      assert render(lv) =~ "Workspace renamed"
    end

    test "shows members list", %{conn: conn, scope: scope} do
      {:ok, _lv, html} = live(conn, ~p"/workspace/settings")
      assert html =~ scope.user.email
      assert html =~ "owner"
    end

    test "owner sees danger zone", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/workspace/settings")
      assert html =~ "Danger Zone"
      assert html =~ "Delete Workspace"
    end

    test "redirects unauthenticated", %{conn: conn} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.delete_session(:user_token)

      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/workspace/settings")
      assert path =~ "/users/log-in"
    end
  end

  describe "Invitations" do
    import Swoosh.TestAssertions

    alias Onesqlx.AccountsFixtures
    alias Onesqlx.Workspaces

    test "owner sees the invite form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/workspace/settings")
      assert has_element?(lv, "#invite-form")
    end

    test "a plain member does not see the invite form", %{conn: conn, scope: scope} do
      member = AccountsFixtures.user_fixture()
      {:ok, _} = Workspaces.add_member(scope.workspace, member, "member")

      conn =
        conn
        |> log_in_user(member)
        |> Plug.Conn.put_session(:workspace_id, scope.workspace.id)

      {:ok, lv, _html} = live(conn, ~p"/workspace/settings")
      refute has_element?(lv, "#invite-form")
    end

    test "inviting sends the email and lists the pending invitation", %{
      conn: conn,
      scope: scope
    } do
      {:ok, lv, _html} = live(conn, ~p"/workspace/settings")
      flush_fixture_emails()

      lv
      |> form("#invite-form", invitation: %{email: "friend@example.com", role: "viewer"})
      |> render_submit()

      assert render(lv) =~ "Invitation sent to friend@example.com"
      assert render(lv) =~ "friend@example.com"

      assert_email_sent(fn email ->
        assert email.subject =~ scope.workspace.name
        assert email.text_body =~ "/invitations/"
      end)

      assert [invitation] = Workspaces.list_pending_invitations(scope.workspace)
      assert invitation.role == "viewer"
    end

    test "inviting an existing member shows an error", %{conn: conn, scope: scope} do
      {:ok, lv, _html} = live(conn, ~p"/workspace/settings")
      flush_fixture_emails()

      lv
      |> form("#invite-form", invitation: %{email: scope.user.email, role: "member"})
      |> render_submit()

      assert render(lv) =~ "already a member"
      assert_no_email_sent()
    end

    test "owner can revoke a pending invitation", %{conn: conn, scope: scope} do
      owner_scope = %{scope | role: "owner"}
      {:ok, invitation, _raw} = Workspaces.invite_member(owner_scope, "x@example.com", "member")

      {:ok, lv, _html} = live(conn, ~p"/workspace/settings")

      lv
      |> element("#revoke-invitation-#{invitation.id}")
      |> render_click()

      assert render(lv) =~ "Invitation revoked"
      assert Workspaces.list_pending_invitations(scope.workspace) == []
    end
  end

  # user_fixture/0 delivers confirmation emails to this process; drain
  # them so assertions only see the invitation email
  defp flush_fixture_emails do
    receive do
      {:email, _} -> flush_fixture_emails()
    after
      0 -> :ok
    end
  end
end
