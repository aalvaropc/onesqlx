defmodule OnesqlxWeb.AnalyticsLiveTest do
  use OnesqlxWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Onesqlx.AuditFixtures
  import Onesqlx.DataSourcesFixtures
  import Onesqlx.QueryingFixtures

  setup :register_and_log_in_user

  describe "Analytics" do
    test "renders page with KPI cards", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/analytics")
      assert html =~ "Usage Analytics"
      assert html =~ "Total Queries"
      assert html =~ "Success Rate"
      assert html =~ "Avg Duration"
      assert html =~ "Active Users"
    end

    test "shows zero metrics when no data", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/analytics")
      assert html =~ "0"
    end

    test "shows query stats when data exists", %{conn: conn, scope: scope} do
      ds = data_source_fixture(scope)
      query_run_fixture(scope, ds, %{status: "success", duration_ms: 100})
      query_run_fixture(scope, ds, %{status: "success", duration_ms: 200})

      {:ok, _lv, html} = live(conn, ~p"/analytics")
      assert html =~ "2"
    end

    test "shows slowest queries", %{conn: conn, scope: scope} do
      ds = data_source_fixture(scope)

      query_run_fixture(scope, ds, %{
        sql: "SELECT slow_query",
        status: "success",
        duration_ms: 5000
      })

      {:ok, _lv, html} = live(conn, ~p"/analytics")
      assert html =~ "slow_query"
      assert html =~ "5000ms"
    end

    test "shows recent activity", %{conn: conn, scope: scope} do
      audit_event_fixture(scope, "query.executed")

      {:ok, _lv, html} = live(conn, ~p"/analytics")
      assert html =~ "query.executed"
    end

    test "changes date range", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/analytics")

      html = lv |> element("button", "7d") |> render_click()
      assert html =~ "Usage Analytics"
    end

    test "redirects unauthenticated to login", %{conn: conn} do
      conn = log_out(conn)
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/analytics")
      assert path =~ "/users/log-in"
    end
  end

  defp log_out(conn) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.delete_session(:user_token)
  end
end
