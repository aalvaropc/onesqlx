defmodule OnesqlxWeb.Api.ScheduledQueryControllerTest do
  use OnesqlxWeb.ConnCase, async: true

  import Onesqlx.AccountsFixtures
  import Onesqlx.DataSourcesFixtures
  import Onesqlx.SavedQueriesFixtures
  import Onesqlx.SchedulingFixtures

  setup do
    scope = user_scope_fixture()
    {:ok, raw, _token} = Onesqlx.Accounts.create_api_token(scope, "test-key")
    data_source = data_source_fixture(scope)
    saved_query = saved_query_fixture(scope, data_source)
    %{scope: scope, raw_token: raw, saved_query: saved_query}
  end

  defp auth_conn(conn, raw_token) do
    put_req_header(conn, "authorization", "Bearer #{raw_token}")
  end

  describe "GET /api/v1/schedules" do
    test "lists schedules", %{conn: conn, raw_token: raw, scope: scope, saved_query: sq} do
      scheduled_query_fixture(scope, sq, %{name: "Daily Report"})

      conn = conn |> auth_conn(raw) |> get("/api/v1/schedules")
      assert %{"data" => [%{"name" => "Daily Report"}]} = json_response(conn, 200)
    end

    test "returns 401 without token", %{conn: conn} do
      conn = get(conn, "/api/v1/schedules")
      assert json_response(conn, 401)["error"]["code"] == "unauthorized"
    end
  end

  describe "GET /api/v1/schedules/:id" do
    test "returns single schedule", %{conn: conn, raw_token: raw, scope: scope, saved_query: sq} do
      schedule = scheduled_query_fixture(scope, sq, %{name: "My Schedule"})

      conn = conn |> auth_conn(raw) |> get("/api/v1/schedules/#{schedule.id}")
      assert %{"data" => %{"name" => "My Schedule"}} = json_response(conn, 200)
    end
  end

  describe "POST /api/v1/schedules" do
    test "creates a schedule", %{conn: conn, raw_token: raw, saved_query: sq} do
      params = %{
        "schedule" => %{
          "name" => "New Schedule",
          "schedule_type" => "hourly",
          "saved_query_id" => sq.id
        }
      }

      conn = conn |> auth_conn(raw) |> post("/api/v1/schedules", params)
      assert %{"data" => %{"name" => "New Schedule"}} = json_response(conn, 201)
    end

    test "returns 422 for invalid params", %{conn: conn, raw_token: raw} do
      params = %{"schedule" => %{"name" => ""}}

      conn = conn |> auth_conn(raw) |> post("/api/v1/schedules", params)
      assert %{"error" => %{"code" => "validation_error"}} = json_response(conn, 422)
    end
  end

  describe "PUT /api/v1/schedules/:id" do
    test "updates a schedule", %{conn: conn, raw_token: raw, scope: scope, saved_query: sq} do
      schedule = scheduled_query_fixture(scope, sq, %{name: "Old Name"})

      params = %{"schedule" => %{"name" => "New Name"}}
      conn = conn |> auth_conn(raw) |> put("/api/v1/schedules/#{schedule.id}", params)
      assert %{"data" => %{"name" => "New Name"}} = json_response(conn, 200)
    end
  end

  describe "DELETE /api/v1/schedules/:id" do
    test "deletes a schedule", %{conn: conn, raw_token: raw, scope: scope, saved_query: sq} do
      schedule = scheduled_query_fixture(scope, sq)

      conn = conn |> auth_conn(raw) |> delete("/api/v1/schedules/#{schedule.id}")
      assert response(conn, 204)
    end
  end
end
