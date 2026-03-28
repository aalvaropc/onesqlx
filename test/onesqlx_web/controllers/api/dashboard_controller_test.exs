defmodule OnesqlxWeb.Api.DashboardControllerTest do
  use OnesqlxWeb.ConnCase, async: true

  import Onesqlx.AccountsFixtures
  import Onesqlx.DashboardsFixtures

  setup do
    scope = user_scope_fixture()
    {:ok, raw, _token} = Onesqlx.Accounts.create_api_token(scope, "test-key")
    %{scope: scope, raw_token: raw}
  end

  defp auth_conn(conn, raw_token) do
    put_req_header(conn, "authorization", "Bearer #{raw_token}")
  end

  describe "GET /api/dashboards" do
    test "lists dashboards", %{conn: conn, raw_token: raw, scope: scope} do
      dashboard_fixture(scope, %{title: "Sales Dashboard"})

      conn = conn |> auth_conn(raw) |> get("/api/dashboards")
      assert %{"data" => [%{"title" => "Sales Dashboard"}]} = json_response(conn, 200)
    end

    test "returns 401 without token", %{conn: conn} do
      conn = get(conn, "/api/dashboards")
      assert json_response(conn, 401)
    end
  end

  describe "GET /api/dashboards/:id" do
    test "returns dashboard with cards", %{conn: conn, raw_token: raw, scope: scope} do
      dashboard = dashboard_fixture(scope, %{title: "Detail Dashboard"})

      conn = conn |> auth_conn(raw) |> get("/api/dashboards/#{dashboard.id}")

      response = json_response(conn, 200)
      assert response["data"]["title"] == "Detail Dashboard"
      assert is_list(response["data"]["cards"])
    end
  end
end
