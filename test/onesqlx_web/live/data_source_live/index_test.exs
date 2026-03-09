defmodule OnesqlxWeb.DataSourceLive.IndexTest do
  use OnesqlxWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Onesqlx.DataSourcesFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders empty state when no data sources exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/data-sources")
      assert html =~ "Data Sources"
      assert html =~ "No data sources yet"
    end

    test "lists data sources", %{conn: conn, scope: scope} do
      _ds =
        data_source_fixture(scope, %{
          name: "my-test-db",
          host: "db.example.com",
          database_name: "analytics"
        })

      {:ok, _view, html} = live(conn, ~p"/data-sources")

      assert html =~ "my-test-db"
      assert html =~ "db.example.com"
      assert html =~ "analytics"
      assert html =~ "pending"
    end

    test "has link to new data source", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/data-sources")
      assert has_element?(view, "a[href='/data-sources/new']")
    end
  end
end
