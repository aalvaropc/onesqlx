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
end
