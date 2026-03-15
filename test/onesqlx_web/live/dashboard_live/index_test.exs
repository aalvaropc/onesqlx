defmodule OnesqlxWeb.DashboardLive.IndexTest do
  use OnesqlxWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Onesqlx.DashboardsFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders empty state when no dashboards", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/dashboards")
      assert html =~ "No dashboards yet"
    end

    test "lists dashboards by title", %{conn: conn, scope: scope} do
      dashboard = dashboard_fixture(scope, %{title: "Revenue Overview"})

      {:ok, _lv, html} = live(conn, ~p"/dashboards")
      assert html =~ dashboard.title
    end

    test "opens create modal on button click", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/dashboards")

      lv |> element("button", "New Dashboard") |> render_click()

      assert has_element?(lv, "#new-dashboard-form")
    end

    test "creates dashboard via modal", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/dashboards")

      lv |> element("button", "New Dashboard") |> render_click()

      lv
      |> form("#new-dashboard-form", dashboard: %{title: "My New Dashboard"})
      |> render_submit()

      assert has_element?(lv, "#dashboards", "My New Dashboard")
    end

    test "deletes dashboard", %{conn: conn, scope: scope} do
      dashboard = dashboard_fixture(scope, %{title: "To Delete"})

      {:ok, lv, _html} = live(conn, ~p"/dashboards")
      assert has_element?(lv, "#dashboards", "To Delete")

      lv
      |> element("[phx-click='delete'][phx-value-id='#{dashboard.id}']")
      |> render_click()

      refute has_element?(lv, "#dashboards", "To Delete")
    end

    test "redirects unauthenticated to login", %{conn: conn} do
      conn = log_out(conn)
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/dashboards")
      assert path =~ "/users/log-in"
    end
  end

  defp log_out(conn) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.delete_session(:user_token)
  end
end
