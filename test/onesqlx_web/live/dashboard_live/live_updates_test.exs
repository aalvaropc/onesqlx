defmodule OnesqlxWeb.DashboardLive.LiveUpdatesTest do
  use OnesqlxWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Onesqlx.AccountsFixtures
  import Onesqlx.DashboardsFixtures

  alias Onesqlx.Dashboards

  describe "Show live updates" do
    setup :register_and_log_in_user

    test "reflects a card added by another process", %{conn: conn, scope: scope} do
      dashboard = dashboard_fixture(scope)

      {:ok, lv, html} = live(conn, ~p"/dashboards/#{dashboard.id}")
      refute html =~ "Untitled Card"

      # The test process plays the "other user": it is not the LV process,
      # so the broadcast reaches the LV
      {:ok, _card} = Dashboards.add_card(scope, dashboard, %{type: "table"})

      assert render(lv) =~ "Untitled Card"
    end

    test "reflects variables defined by another process", %{conn: conn, scope: scope} do
      dashboard = dashboard_fixture(scope)

      {:ok, lv, html} = live(conn, ~p"/dashboards/#{dashboard.id}")
      refute html =~ ~s(name="params[region]")

      {:ok, _} = Dashboards.update_variables(scope, dashboard, [%{"name" => "region"}])

      assert render(lv) =~ ~s(name="params[region]")
    end
  end

  describe "Public view live updates" do
    test "reflects a card added while viewing", %{conn: conn} do
      scope = user_scope_fixture()
      dashboard = dashboard_fixture(scope)
      {:ok, dashboard} = Dashboards.generate_public_token(scope, dashboard)

      {:ok, lv, html} = live(conn, ~p"/share/#{dashboard.public_token}")
      refute html =~ "Untitled Card"

      {:ok, _card} = Dashboards.add_card(scope, dashboard, %{type: "table"})

      assert render(lv) =~ "Untitled Card"
    end
  end
end
