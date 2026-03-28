defmodule OnesqlxWeb.ScheduledQueryLive.IndexTest do
  use OnesqlxWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Onesqlx.DataSourcesFixtures
  import Onesqlx.SavedQueriesFixtures
  import Onesqlx.SchedulingFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders empty state when no schedules", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/schedules")
      assert html =~ "No scheduled queries yet"
    end

    test "lists schedules by name", %{conn: conn, scope: scope} do
      ds = data_source_fixture(scope)
      sq = saved_query_fixture(scope, ds)
      scheduled_query_fixture(scope, sq, %{name: "Daily Sales"})

      {:ok, _lv, html} = live(conn, ~p"/schedules")
      assert html =~ "Daily Sales"
    end

    test "opens create modal", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/schedules")

      lv |> element("button", "New Schedule") |> render_click()
      assert has_element?(lv, "#new-schedule-form")
    end

    test "creates schedule via modal", %{conn: conn, scope: scope} do
      ds = data_source_fixture(scope)
      sq = saved_query_fixture(scope, ds)

      {:ok, lv, _html} = live(conn, ~p"/schedules")

      lv |> element("button", "New Schedule") |> render_click()

      lv
      |> form("#new-schedule-form",
        schedule: %{name: "New Report", saved_query_id: sq.id, schedule_type: "daily"}
      )
      |> render_submit()

      assert has_element?(lv, "#schedules", "New Report")
    end

    test "toggles enabled state", %{conn: conn, scope: scope} do
      ds = data_source_fixture(scope)
      sq = saved_query_fixture(scope, ds)
      sched = scheduled_query_fixture(scope, sq, %{name: "Toggle Me", enabled: true})

      {:ok, lv, html} = live(conn, ~p"/schedules")
      assert html =~ "Active"

      lv
      |> element("[phx-click='toggle_enabled'][phx-value-id='#{sched.id}']")
      |> render_click()

      assert has_element?(lv, "#schedules", "Disabled")
    end

    test "deletes schedule", %{conn: conn, scope: scope} do
      ds = data_source_fixture(scope)
      sq = saved_query_fixture(scope, ds)
      sched = scheduled_query_fixture(scope, sq, %{name: "Delete Me"})

      {:ok, lv, _html} = live(conn, ~p"/schedules")
      assert has_element?(lv, "#schedules", "Delete Me")

      lv
      |> element("[phx-click='delete'][phx-value-id='#{sched.id}']")
      |> render_click()

      refute has_element?(lv, "#schedules", "Delete Me")
    end

    test "redirects unauthenticated to login", %{conn: conn} do
      conn = log_out(conn)
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/schedules")
      assert path =~ "/users/log-in"
    end
  end

  defp log_out(conn) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.delete_session(:user_token)
  end
end
