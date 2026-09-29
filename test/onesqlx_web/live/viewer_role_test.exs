defmodule OnesqlxWeb.ViewerRoleTest do
  use OnesqlxWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Onesqlx.AccountsFixtures
  import Onesqlx.DashboardsFixtures

  alias Onesqlx.Workspaces

  # A real viewer: a second user added to the owner's workspace with the
  # viewer role, mounted with that workspace selected in the session so
  # UserAuth.build_scope resolves role: "viewer" from the membership.
  setup %{conn: conn} do
    owner_scope = user_scope_fixture()

    viewer = user_fixture()
    {:ok, _} = Workspaces.add_member(owner_scope.workspace, viewer, "viewer")

    conn =
      conn
      |> log_in_user(viewer)
      |> Plug.Conn.put_session(:workspace_id, owner_scope.workspace.id)

    %{conn: conn, owner: owner_scope}
  end

  test "dashboards index hides creation and deletion", %{conn: conn, owner: owner} do
    dashboard_fixture(owner, %{title: "Shared numbers"})

    {:ok, _lv, html} = live(conn, ~p"/dashboards")

    assert html =~ "Shared numbers"
    refute html =~ "New Dashboard"
  end

  test "dashboard show hides edit, share, and duplicate", %{conn: conn, owner: owner} do
    dashboard = dashboard_fixture(owner)

    {:ok, _lv, html} = live(conn, ~p"/dashboards/#{dashboard.id}")

    refute html =~ ~s(phx-click="toggle_edit")
    refute html =~ ~s(phx-click="toggle_share")
    refute html =~ ~s(phx-click="duplicate_dashboard")
    # Reading stays available
    assert html =~ ~s(phx-click="refresh")
  end

  test "sql editor hides save but keeps run", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/sql-editor")

    refute html =~ ~s(phx-click="open_save_modal")
    refute html =~ ~s(phx-click="open_snippet_modal")
    assert html =~ ~s(phx-click="execute")
  end

  test "data sources index hides new and edit but keeps explore", %{conn: conn, owner: owner} do
    Onesqlx.DataSourcesFixtures.data_source_fixture(owner)

    {:ok, _lv, html} = live(conn, ~p"/data-sources")

    refute html =~ "New Data Source"
    refute html =~ ">Edit<"
    assert html =~ "Explore"
  end

  test "crafted create events still hit the context wall", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/dashboards")

    # The UI hides the button, so this simulates a hand-crafted event.
    # The LiveView process crashes with the authorization error; trap the
    # linked exit and assert on the reason.
    Process.flag(:trap_exit, true)
    catch_exit(render_submit(lv, "create_dashboard", %{"dashboard" => %{"title" => "sneaky"}}))

    assert_receive {:EXIT, _pid, {%Ecto.NoResultsError{}, _stacktrace}}
  end
end
