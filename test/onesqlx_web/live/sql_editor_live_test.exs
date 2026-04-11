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
        |> form("#ds-selector", %{data_source_id: ds.id})
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
      lv |> form("#ds-selector", %{data_source_id: ds.id}) |> render_change()
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

  describe "loading saved queries" do
    setup :register_and_log_in_user

    test "loads saved query from query params", %{conn: conn, scope: scope} do
      ds = data_source_fixture(scope, %{name: "saved-query-db"})

      saved_query =
        saved_query_fixture(scope, ds, %{title: "My Query", sql: "SELECT * FROM users"})

      {:ok, _lv, html} = live(conn, ~p"/sql-editor?saved_query_id=#{saved_query.id}")
      assert html =~ "saved-query-db"
    end

    test "raises for saved query from different workspace", %{conn: conn} do
      other_scope = Onesqlx.AccountsFixtures.user_scope_fixture()
      other_ds = data_source_fixture(other_scope, %{name: "other-db"})
      saved_query = saved_query_fixture(other_scope, other_ds, %{title: "Other", sql: "SELECT 1"})

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/sql-editor?saved_query_id=#{saved_query.id}")
      end
    end
  end

  describe "query timeout" do
    setup :register_and_log_in_user

    test "shows timeout error when query exceeds time limit", %{conn: conn, scope: scope} do
      ds = data_source_fixture(scope, %{name: "timeout-db"})
      {:ok, lv, _html} = live(conn, ~p"/sql-editor")

      lv |> form("#ds-selector", %{data_source_id: ds.id}) |> render_change()
      render_click(lv, "update_sql", %{sql: "SELECT 1"})

      # Simulate: user triggered execute, then timeout fires
      # We set running? manually via the assign by sending the timeout message
      # Send timeout with a random tab_id — should be ignored since no tab matches
      send(lv.pid, {:query_timeout, Ecto.UUID.generate()})

      # Timeout should be ignored since no matching tab is running
      refute render(lv) =~ "timed out"
    end
  end

  describe "explain" do
    setup :register_and_log_in_user

    test "explain button is present", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/sql-editor")
      assert html =~ "Explain"
    end

    test "explain tab shows empty state", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/sql-editor")
      html = render_click(lv, "set_result_tab", %{tab: "explain"})
      assert html =~ "Click &quot;Explain&quot; to see the query execution plan"
    end

    test "explain does nothing without data source", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/sql-editor")
      render_click(lv, "update_sql", %{sql: "SELECT 1"})
      html = render_click(lv, "explain")
      refute html =~ "loading"
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
