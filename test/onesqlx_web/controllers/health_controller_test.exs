defmodule OnesqlxWeb.HealthControllerTest do
  use OnesqlxWeb.ConnCase, async: true

  describe "GET /health" do
    test "returns 200 ok", %{conn: conn} do
      conn = get(conn, "/health")
      assert json_response(conn, 200) == %{"status" => "ok"}
    end
  end

  describe "GET /ready" do
    test "returns 200 with checks when healthy", %{conn: conn} do
      conn = get(conn, "/ready")
      response = json_response(conn, 200)
      assert response["status"] == "ok"
      assert response["checks"]["database"] == "ok"
    end
  end
end
