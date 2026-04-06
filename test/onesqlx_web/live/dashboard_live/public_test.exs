defmodule OnesqlxWeb.DashboardLive.PublicTest do
  use OnesqlxWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Onesqlx.AccountsFixtures
  import Onesqlx.DashboardsFixtures

  alias Onesqlx.Dashboards

  describe "Public" do
    test "renders shared dashboard without auth", %{conn: conn} do
      scope = user_scope_fixture()
      dashboard = dashboard_fixture(scope, %{title: "Public Dashboard"})
      {:ok, dashboard} = Dashboards.generate_public_token(scope, dashboard)

      {:ok, _lv, html} = live(conn, ~p"/share/#{dashboard.public_token}")
      assert html =~ "Public Dashboard"
      assert html =~ "Powered by OneSQLx"
    end

    test "raises for invalid token", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/share/#{Ecto.UUID.generate()}")
      end
    end
  end
end
