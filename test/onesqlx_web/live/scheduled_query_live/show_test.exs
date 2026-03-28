defmodule OnesqlxWeb.ScheduledQueryLive.ShowTest do
  use OnesqlxWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Onesqlx.DataSourcesFixtures
  import Onesqlx.SavedQueriesFixtures
  import Onesqlx.SchedulingFixtures

  alias Onesqlx.Scheduling

  setup :register_and_log_in_user

  describe "Show" do
    test "renders scheduled query details", %{conn: conn, scope: scope} do
      ds = data_source_fixture(scope)
      sq = saved_query_fixture(scope, ds)
      sched = scheduled_query_fixture(scope, sq, %{name: "My Schedule"})

      {:ok, _lv, html} = live(conn, ~p"/schedules/#{sched.id}")
      assert html =~ "My Schedule"
      assert html =~ "daily"
    end

    test "shows run history", %{conn: conn, scope: scope} do
      ds = data_source_fixture(scope)
      sq = saved_query_fixture(scope, ds)
      sched = scheduled_query_fixture(scope, sq)

      {:ok, _} =
        Scheduling.record_run(sched, %{
          status: "success",
          started_at: DateTime.utc_now(:second),
          duration_ms: 42,
          row_count: 10
        })

      {:ok, _lv, html} = live(conn, ~p"/schedules/#{sched.id}")
      assert html =~ "success"
      assert html =~ "42ms"
    end

    test "shows empty run history message", %{conn: conn, scope: scope} do
      ds = data_source_fixture(scope)
      sq = saved_query_fixture(scope, ds)
      sched = scheduled_query_fixture(scope, sq)

      {:ok, _lv, html} = live(conn, ~p"/schedules/#{sched.id}")
      assert html =~ "No runs yet"
    end

    test "run now button is present", %{conn: conn, scope: scope} do
      ds = data_source_fixture(scope)
      sq = saved_query_fixture(scope, ds)
      sched = scheduled_query_fixture(scope, sq)

      {:ok, lv, _html} = live(conn, ~p"/schedules/#{sched.id}")
      assert has_element?(lv, "button", "Run Now")
    end

    test "back link navigates to index", %{conn: conn, scope: scope} do
      ds = data_source_fixture(scope)
      sq = saved_query_fixture(scope, ds)
      sched = scheduled_query_fixture(scope, sq)

      {:ok, lv, _html} = live(conn, ~p"/schedules/#{sched.id}")
      assert has_element?(lv, "a[href='/schedules']")
    end

    test "redirects unauthenticated to login", %{conn: conn, scope: scope} do
      ds = data_source_fixture(scope)
      sq = saved_query_fixture(scope, ds)
      sched = scheduled_query_fixture(scope, sq)

      conn = log_out(conn)
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/schedules/#{sched.id}")
      assert path =~ "/users/log-in"
    end
  end

  defp log_out(conn) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.delete_session(:user_token)
  end
end
