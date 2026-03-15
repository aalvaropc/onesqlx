defmodule OnesqlxWeb.DashboardLive.ShowTest do
  use OnesqlxWeb.ConnCase, async: true

  import Mox
  import Phoenix.LiveViewTest
  import Onesqlx.DataSourcesFixtures
  import Onesqlx.SavedQueriesFixtures
  import Onesqlx.DashboardsFixtures

  alias Onesqlx.DataSources.MockConnection

  setup :verify_on_exit!
  setup :register_and_log_in_user

  describe "Show" do
    test "renders dashboard title", %{conn: conn, scope: scope} do
      dashboard = dashboard_fixture(scope, %{title: "My Dashboard"})

      {:ok, _lv, html} = live(conn, ~p"/dashboards/#{dashboard.id}")
      assert html =~ "My Dashboard"
    end

    test "shows error state for cards without saved query", %{conn: conn, scope: scope} do
      dashboard = dashboard_fixture(scope)
      {:ok, _card} = Onesqlx.Dashboards.add_card(scope, dashboard, %{type: "table"})

      {:ok, _lv, html} = live(conn, ~p"/dashboards/#{dashboard.id}")
      assert html =~ "No query assigned"
    end

    test "shows loading state for cards with queries before async resolves", %{
      conn: conn,
      scope: scope
    } do
      data_source = data_source_fixture(scope)
      saved_query = saved_query_fixture(scope, data_source)
      dashboard = dashboard_fixture(scope)

      stub(MockConnection, :with_connection, fn _ds, _fun ->
        Process.sleep(:infinity)
      end)

      card_fixture(scope, dashboard, saved_query)

      {:ok, lv, _html} = live(conn, ~p"/dashboards/#{dashboard.id}")
      assert render(lv) =~ "loading"
    end

    test "resolves card result after async completes", %{conn: conn, scope: scope} do
      data_source = data_source_fixture(scope)
      saved_query = saved_query_fixture(scope, data_source, %{sql: "SELECT 1 AS val"})
      dashboard = dashboard_fixture(scope)

      stub(MockConnection, :with_connection, fn _ds, _fun ->
        {:ok, %{columns: ["val"], rows: [[1]], row_count: 1, duration_ms: 5}}
      end)

      card_fixture(scope, dashboard, saved_query)

      {:ok, lv, _html} = live(conn, ~p"/dashboards/#{dashboard.id}")
      render_async(lv, 2000)
      refute render(lv) =~ "loading loading-spinner"
    end

    test "toggles edit mode", %{conn: conn, scope: scope} do
      dashboard = dashboard_fixture(scope)

      {:ok, lv, _html} = live(conn, ~p"/dashboards/#{dashboard.id}")
      refute has_element?(lv, "button", "Add Card")

      lv |> element("button", "Edit") |> render_click()
      assert has_element?(lv, "button", "Add Card")

      lv |> element("button", "Done") |> render_click()
      refute has_element?(lv, "button", "Add Card")
    end

    test "removes a card in edit mode", %{conn: conn, scope: scope} do
      data_source = data_source_fixture(scope)
      saved_query = saved_query_fixture(scope, data_source)
      dashboard = dashboard_fixture(scope)

      stub(MockConnection, :with_connection, fn _ds, _fun ->
        Process.sleep(:infinity)
      end)

      card = card_fixture(scope, dashboard, saved_query)

      {:ok, lv, _html} = live(conn, ~p"/dashboards/#{dashboard.id}")

      lv |> element("button", "Edit") |> render_click()

      lv
      |> element("[phx-click='remove_card'][phx-value-id='#{card.id}']")
      |> render_click()

      refute has_element?(lv, "#card-#{card.id}")
    end

    test "open in editor link present for card with saved_query_id", %{conn: conn, scope: scope} do
      data_source = data_source_fixture(scope)
      saved_query = saved_query_fixture(scope, data_source)
      dashboard = dashboard_fixture(scope)

      stub(MockConnection, :with_connection, fn _ds, _fun ->
        Process.sleep(:infinity)
      end)

      card_fixture(scope, dashboard, saved_query)

      {:ok, lv, _html} = live(conn, ~p"/dashboards/#{dashboard.id}")
      lv |> element("button", "Edit") |> render_click()

      assert has_element?(lv, "a[href*='/sql-editor']")
    end

    test "add card modal opens in edit mode", %{conn: conn, scope: scope} do
      dashboard = dashboard_fixture(scope)

      {:ok, lv, _html} = live(conn, ~p"/dashboards/#{dashboard.id}")
      lv |> element("button", "Edit") |> render_click()
      lv |> element("button", "Add Card") |> render_click()

      assert has_element?(lv, "#add-card-form")
    end

    test "redirects unauthenticated to login", %{conn: conn, scope: scope} do
      dashboard = dashboard_fixture(scope)
      conn = log_out(conn)

      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/dashboards/#{dashboard.id}")
      assert path =~ "/users/log-in"
    end
  end

  defp log_out(conn) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.delete_session(:user_token)
  end
end
