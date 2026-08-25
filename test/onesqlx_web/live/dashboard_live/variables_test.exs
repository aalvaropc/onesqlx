defmodule OnesqlxWeb.DashboardLive.VariablesTest do
  use OnesqlxWeb.ConnCase, async: true

  import Mox
  import Phoenix.LiveViewTest
  import Onesqlx.AccountsFixtures
  import Onesqlx.DashboardsFixtures
  import Onesqlx.DataSourcesFixtures
  import Onesqlx.SavedQueriesFixtures

  alias Onesqlx.Dashboards

  setup :register_and_log_in_user

  describe "variables management in Show" do
    test "adds a variable from the modal and shows it in the filter bar", %{
      conn: conn,
      scope: scope
    } do
      dashboard = dashboard_fixture(scope)
      {:ok, lv, _html} = live(conn, ~p"/dashboards/#{dashboard.id}")

      lv |> element("button[phx-click=toggle_edit]") |> render_click()
      lv |> element("button[phx-click=open_variables_modal]") |> render_click()

      html =
        lv
        |> form("form[phx-submit=add_variable]",
          variable: %{name: "category", type: "text", default: "books"}
        )
        |> render_submit()

      assert html =~ "category"
      assert html =~ ~s(name="params[category]")
      # The default prefills the filter input
      assert html =~ ~s(value="books")
    end

    test "rejects an invalid variable name with a flash", %{conn: conn, scope: scope} do
      dashboard = dashboard_fixture(scope)
      {:ok, lv, _html} = live(conn, ~p"/dashboards/#{dashboard.id}")

      lv |> element("button[phx-click=toggle_edit]") |> render_click()
      lv |> element("button[phx-click=open_variables_modal]") |> render_click()

      html =
        lv
        |> form("form[phx-submit=add_variable]", variable: %{name: "bad name!", type: "text"})
        |> render_submit()

      assert html =~ "valid identifiers"
    end

    test "removes a variable", %{conn: conn, scope: scope} do
      dashboard = dashboard_fixture(scope)

      {:ok, _} =
        Dashboards.update_variables(scope, dashboard, [%{"name" => "region", "type" => "text"}])

      {:ok, lv, html} = live(conn, ~p"/dashboards/#{dashboard.id}")
      assert html =~ ~s(name="params[region]")

      lv |> element("button[phx-click=toggle_edit]") |> render_click()
      lv |> element("button[phx-click=open_variables_modal]") |> render_click()

      html =
        lv
        |> element("button[phx-click=remove_variable][phx-value-name=region]")
        |> render_click()

      refute html =~ ~s(name="params[region]")
    end
  end

  describe "public view URL parameters" do
    setup do
      %{owner: user_scope_fixture()}
    end

    test "allowlisted params show as applied filters", %{conn: conn, owner: scope} do
      dashboard = dashboard_fixture(scope)

      {:ok, dashboard} =
        Dashboards.update_variables(scope, dashboard, [%{"name" => "category"}])

      {:ok, dashboard} = Dashboards.generate_public_token(scope, dashboard)

      {:ok, _lv, html} =
        live(conn, ~p"/share/#{dashboard.public_token}?category=books")

      assert html =~ "category = books"
    end

    test "non-allowlisted params are dropped", %{conn: conn, owner: scope} do
      dashboard = dashboard_fixture(scope)
      {:ok, dashboard} = Dashboards.generate_public_token(scope, dashboard)

      {:ok, _lv, html} =
        live(conn, ~p"/share/#{dashboard.public_token}?evil=1")

      refute html =~ "evil"
    end

    test "variable defaults apply without URL params", %{conn: conn, owner: scope} do
      dashboard = dashboard_fixture(scope)

      {:ok, dashboard} =
        Dashboards.update_variables(scope, dashboard, [
          %{"name" => "region", "default" => "emea"}
        ])

      {:ok, dashboard} = Dashboards.generate_public_token(scope, dashboard)

      {:ok, _lv, html} = live(conn, ~p"/share/#{dashboard.public_token}")

      assert html =~ "region = emea"
    end
  end

  describe "card CSV export" do
    setup :register_and_log_in_user
    setup :verify_on_exit!

    test "the export form carries the dashboard's parameter values", %{
      conn: conn,
      scope: scope
    } do
      data_source = data_source_fixture(scope)

      saved_query =
        saved_query_fixture(scope, data_source, %{
          title: "By region",
          sql: "SELECT count(*) FROM orders WHERE region = :region"
        })

      dashboard = dashboard_fixture(scope)

      {:ok, dashboard} =
        Onesqlx.Dashboards.update_variables(scope, dashboard, [
          %{"name" => "region", "default" => "emea"}
        ])

      card_fixture(scope, dashboard, saved_query, %{type: "table"})

      stub(Onesqlx.DataSources.MockConnection, :with_connection, fn _ds, _fun ->
        {:ok, %{columns: ["count"], rows: [[7]], row_count: 1, duration_ms: 1}}
      end)

      {:ok, lv, _html} = live(conn, ~p"/dashboards/#{dashboard.id}")
      html = render_async(lv)

      # The card ran with region=emea, so its export must too
      assert html =~ ~s(name="params[region]" value="emea")
    end
  end
end
