defmodule OnesqlxWeb.Api.SavedQueryControllerTest do
  use OnesqlxWeb.ConnCase, async: true

  import Onesqlx.AccountsFixtures
  import Onesqlx.DataSourcesFixtures
  import Onesqlx.SavedQueriesFixtures

  setup do
    scope = user_scope_fixture()
    {:ok, raw, _token} = Onesqlx.Accounts.create_api_token(scope, "test-key")
    data_source = data_source_fixture(scope)
    %{scope: scope, raw_token: raw, data_source: data_source}
  end

  defp auth_conn(conn, raw_token) do
    put_req_header(conn, "authorization", "Bearer #{raw_token}")
  end

  describe "GET /api/saved-queries" do
    test "lists saved queries", %{conn: conn, raw_token: raw, scope: scope, data_source: ds} do
      saved_query_fixture(scope, ds, %{title: "My Query"})

      conn = conn |> auth_conn(raw) |> get("/api/saved-queries")
      assert %{"data" => [%{"title" => "My Query"}]} = json_response(conn, 200)
    end

    test "returns 401 without token", %{conn: conn} do
      conn = get(conn, "/api/saved-queries")
      assert json_response(conn, 401)["errors"]
    end
  end

  describe "GET /api/saved-queries/:id" do
    test "returns single query", %{conn: conn, raw_token: raw, scope: scope, data_source: ds} do
      sq = saved_query_fixture(scope, ds, %{title: "Detail Query"})

      conn = conn |> auth_conn(raw) |> get("/api/saved-queries/#{sq.id}")
      assert %{"data" => %{"title" => "Detail Query", "sql" => _}} = json_response(conn, 200)
    end
  end

  describe "POST /api/saved-queries/:id/execute" do
    test "returns 401 without token", %{conn: conn, scope: scope, data_source: ds} do
      sq = saved_query_fixture(scope, ds)
      conn = post(conn, "/api/saved-queries/#{sq.id}/execute")
      assert json_response(conn, 401)
    end
  end
end
