defmodule OnesqlxWeb.DashboardLive.EmbedTest do
  use OnesqlxWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Onesqlx.AccountsFixtures
  import Onesqlx.DashboardsFixtures

  alias Onesqlx.Dashboards

  describe "Embed" do
    test "renders embedded dashboard without auth", %{conn: conn} do
      scope = user_scope_fixture()
      dashboard = dashboard_fixture(scope, %{title: "Embed Dashboard"})
      {:ok, dashboard} = Dashboards.generate_public_token(scope, dashboard)

      {:ok, _lv, html} = live(conn, ~p"/embed/#{dashboard.public_token}")
      assert html =~ "Embed Dashboard"
      refute html =~ "Powered by OneSQLx"
    end

    test "raises for invalid token", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/embed/#{Ecto.UUID.generate()}")
      end
    end

    test "sets permissive CSP header for iframe embedding", %{conn: conn} do
      scope = user_scope_fixture()
      dashboard = dashboard_fixture(scope, %{title: "CSP Test"})
      {:ok, dashboard} = Dashboards.generate_public_token(scope, dashboard)

      conn = get(conn, ~p"/embed/#{dashboard.public_token}")
      csp = Plug.Conn.get_resp_header(conn, "content-security-policy")
      assert Enum.any?(csp, &String.contains?(&1, "frame-ancestors *"))
    end

    test "shows empty state when no cards", %{conn: conn} do
      scope = user_scope_fixture()
      dashboard = dashboard_fixture(scope, %{title: "Empty Embed"})
      {:ok, dashboard} = Dashboards.generate_public_token(scope, dashboard)

      {:ok, _lv, html} = live(conn, ~p"/embed/#{dashboard.public_token}")
      assert html =~ "no cards yet"
    end
  end
end
