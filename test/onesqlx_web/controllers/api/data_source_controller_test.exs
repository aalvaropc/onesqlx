defmodule OnesqlxWeb.Api.DataSourceControllerTest do
  use OnesqlxWeb.ConnCase, async: true

  import Onesqlx.AccountsFixtures
  import Onesqlx.DataSourcesFixtures

  setup do
    scope = user_scope_fixture()
    {:ok, raw, _token} = Onesqlx.Accounts.create_api_token(scope, "test-key")
    %{scope: scope, raw_token: raw}
  end

  defp auth_conn(conn, raw_token) do
    put_req_header(conn, "authorization", "Bearer #{raw_token}")
  end

  describe "GET /api/data-sources" do
    test "lists data sources without sensitive fields", %{
      conn: conn,
      raw_token: raw,
      scope: scope
    } do
      data_source_fixture(scope, %{name: "prod-db"})

      conn = conn |> auth_conn(raw) |> get("/api/data-sources")
      response = json_response(conn, 200)

      assert [ds] = response["data"]
      assert ds["name"] == "prod-db"
      refute Map.has_key?(ds, "encrypted_password")
      refute Map.has_key?(ds, "password")
    end

    test "returns 401 without token", %{conn: conn} do
      conn = get(conn, "/api/data-sources")
      assert json_response(conn, 401)
    end
  end
end
