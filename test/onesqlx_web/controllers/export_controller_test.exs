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
end
