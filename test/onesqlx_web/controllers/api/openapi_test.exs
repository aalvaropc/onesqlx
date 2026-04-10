defmodule OnesqlxWeb.Api.OpenApiTest do
  use OnesqlxWeb.ConnCase, async: true

  describe "GET /api/openapi" do
    test "returns valid OpenAPI JSON spec", %{conn: conn} do
      conn = get(conn, "/api/openapi")
      spec = json_response(conn, 200)

      assert spec["info"]["title"] == "OneSQLx API"
      assert spec["info"]["version"] == "1.0.0"
      assert is_map(spec["paths"])
      assert Map.has_key?(spec["paths"], "/api/v1/saved-queries")
      assert Map.has_key?(spec["paths"], "/api/v1/dashboards")
      assert Map.has_key?(spec["paths"], "/api/v1/schedules")
      assert Map.has_key?(spec["paths"], "/api/v1/data-sources")
    end

    test "includes security scheme", %{conn: conn} do
      conn = get(conn, "/api/openapi")
      spec = json_response(conn, 200)

      assert get_in(spec, ["components", "securitySchemes", "bearer", "type"]) == "http"
      assert get_in(spec, ["components", "securitySchemes", "bearer", "scheme"]) == "bearer"
    end
  end

  describe "GET /api/docs" do
    test "returns SwaggerUI HTML", %{conn: conn} do
      conn = get(conn, "/api/docs")
      assert html_response(conn, 200) =~ "swagger"
    end
  end
end
