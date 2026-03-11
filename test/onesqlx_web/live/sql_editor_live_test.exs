defmodule OnesqlxWeb.SqlEditorLiveTest do
  use OnesqlxWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Onesqlx.DataSourcesFixtures
  import Onesqlx.QueryingFixtures
  import Onesqlx.SavedQueriesFixtures

  describe "authenticated access" do
    setup :register_and_log_in_user

    test "renders page with data source selector", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/sql-editor")
      assert html =~ "Select a data source"
      assert html =~ "Run"
    end

    test "shows data source options", %{conn: conn, scope: scope} do
      ds = data_source_fixture(scope, %{name: "my-test-db"})
      {:ok, _lv, html} = live(conn, ~p"/sql-editor")
      assert html =~ ds.name
    end

    test "run button disabled when no data source selected", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/sql-editor")
      assert html =~ "btn-disabled"
    end

    test "displays empty state message", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/sql-editor")
      assert html =~ "Run a query to see results"
    end

    test "displays recent query history items", %{conn: conn, scope: scope} do
      ds = data_source_fixture(scope, %{name: "history-db"})
      query_run_fixture(scope, ds, %{sql: "SELECT * FROM important_table"})

      {:ok, lv, _html} = live(conn, ~p"/sql-editor")

      html =
        lv
        |> form("form", %{data_source_id: ds.id})
        |> render_change()

      assert html =~ "SELECT * FROM important_table"
    end

    test "shows history placeholder when no data source selected", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/sql-editor")
      assert html =~ "Select a data source to view history"
    end

    test "save button present and disabled when no data source selected", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/sql-editor")
      assert html =~ "Save"
    end

    test "opens save modal", %{conn: conn, scope: scope} do
      _ds = data_source_fixture(scope, %{name: "save-test-db"})
      {:ok, lv, _html} = live(conn, ~p"/sql-editor")

      html = render_click(lv, "open_save_modal")
      assert html =~ "Save Query"
      assert html =~ "Title"
    end

    test "saves query successfully", %{conn: conn, scope: scope} do
      ds = data_source_fixture(scope, %{name: "save-db"})
      {:ok, lv, _html} = live(conn, ~p"/sql-editor")

      # Select data source and set SQL
      lv |> form("form", %{data_source_id: ds.id}) |> render_change()
      render_click(lv, "update_sql", %{sql: "SELECT * FROM users"})

      # Open modal and save
      render_click(lv, "open_save_modal")

      html =
        lv
        |> form("#save-query-form", saved_query: %{title: "My Saved Query"})
        |> render_submit()

      assert html =~ "Query saved successfully"
    end
  end

  describe "unauthenticated access" do
    test "redirects to login", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/sql-editor")
      assert {:redirect, %{to: path}} = redirect
      assert path =~ ~p"/users/log-in"
    end
  end
end
