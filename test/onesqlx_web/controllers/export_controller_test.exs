defmodule OnesqlxWeb.ExportControllerTest do
  use OnesqlxWeb.ConnCase, async: true

  import Mox
  import Onesqlx.DataSourcesFixtures

  alias Onesqlx.DataSources.MockConnection

  setup :verify_on_exit!
  setup :register_and_log_in_user

  describe "POST /exports/csv" do
    test "returns CSV file on successful query", %{conn: conn, scope: scope} do
      ds = data_source_fixture(scope)

      stub(MockConnection, :with_connection, fn _ds, _fun ->
        {:ok,
         %{
           columns: ["id", "name"],
           rows: [[1, "alice"], [2, "bob"]],
           row_count: 2,
           duration_ms: 10
         }}
      end)

      conn =
        post(conn, ~p"/exports/csv", %{
          "data_source_id" => ds.id,
          "sql" => "SELECT id, name FROM users",
          "label" => "test_export"
        })

      assert response_content_type(conn, :csv) =~ "text/csv"
      assert get_resp_header(conn, "content-disposition") |> hd() =~ "attachment"
      assert get_resp_header(conn, "content-disposition") |> hd() =~ "test_export"

      body = response(conn, 200)
      assert body =~ "id,name"
      assert body =~ "alice"
    end

    test "redirects with flash on query error", %{conn: conn, scope: scope} do
      ds = data_source_fixture(scope)

      stub(MockConnection, :with_connection, fn _ds, _fun ->
        {:error, :execution, "relation does not exist"}
      end)

      conn =
        post(conn, ~p"/exports/csv", %{
          "data_source_id" => ds.id,
          "sql" => "SELECT * FROM missing",
          "label" => "error_export"
        })

      assert redirected_to(conn) == ~p"/sql-editor"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Export failed"
    end

    test "redirects unauthenticated to login", %{conn: conn} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.delete_session(:user_token)
        |> post(~p"/exports/csv", %{
          "data_source_id" => "some-id",
          "sql" => "SELECT 1",
          "label" => "test"
        })

      assert redirected_to(conn) =~ "/users/log-in"
    end
  end

  describe "parameterized exports" do
    test "passes params through to the executor", %{conn: conn, scope: scope} do
      data_source = data_source_fixture(scope)

      stub(MockConnection, :with_connection, fn _ds, _fun ->
        {:ok, %{columns: ["n"], rows: [[42]], row_count: 1, duration_ms: 1}}
      end)

      conn =
        post(conn, ~p"/exports/csv", %{
          "data_source_id" => data_source.id,
          "sql" => "SELECT :n AS n",
          "label" => "params",
          "params" => %{"n" => "42"}
        })

      assert response_content_type(conn, :csv) =~ "text/csv"
      assert conn.resp_body =~ "42"
    end

    test "missing parameter values flash instead of crashing", %{conn: conn, scope: scope} do
      data_source = data_source_fixture(scope)

      conn =
        post(conn, ~p"/exports/csv", %{
          "data_source_id" => data_source.id,
          "sql" => "SELECT :n AS n, :other AS o",
          "label" => "params"
        })

      assert redirected_to(conn) == ~p"/sql-editor"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "missing parameter values: n, other"
    end
  end

  describe "POST /exports/json" do
    test "exports rows as a JSON array of objects", %{conn: conn, scope: scope} do
      data_source = data_source_fixture(scope)

      stub(MockConnection, :with_connection, fn _ds, _fun ->
        {:ok, %{columns: ["id", "name"], rows: [[1, "alice"]], row_count: 1, duration_ms: 1}}
      end)

      conn =
        post(conn, ~p"/exports/json", %{
          "data_source_id" => data_source.id,
          "sql" => "SELECT 1",
          "label" => "people"
        })

      assert response_content_type(conn, :json) =~ "application/json"
      assert Jason.decode!(conn.resp_body) == [%{"id" => 1, "name" => "alice"}]
    end
  end

  describe "POST /exports/xlsx" do
    test "exports a spreadsheet", %{conn: conn, scope: scope} do
      data_source = data_source_fixture(scope)

      stub(MockConnection, :with_connection, fn _ds, _fun ->
        {:ok, %{columns: ["id"], rows: [[1]], row_count: 1, duration_ms: 1}}
      end)

      conn =
        post(conn, ~p"/exports/xlsx", %{
          "data_source_id" => data_source.id,
          "sql" => "SELECT 1",
          "label" => "sheet"
        })

      assert response_content_type(conn, :xlsx) =~ "spreadsheetml"
      # XLSX files are zip archives
      assert <<0x50, 0x4B, _::binary>> = conn.resp_body
    end
  end
end
