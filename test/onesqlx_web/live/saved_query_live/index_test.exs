defmodule OnesqlxWeb.SavedQueryLive.IndexTest do
  use OnesqlxWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Onesqlx.DataSourcesFixtures
  import Onesqlx.SavedQueriesFixtures

  describe "authenticated access" do
    setup :register_and_log_in_user

    test "renders empty state when no saved queries", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/saved-queries")
      assert html =~ "No saved queries found"
      assert html =~ "Saved Queries"
    end

    test "lists saved queries with title and data source name", %{conn: conn, scope: scope} do
      ds = data_source_fixture(scope, %{name: "analytics-db"})
      saved_query_fixture(scope, ds, %{title: "Sales Report", sql: "SELECT * FROM sales"})

      {:ok, _lv, html} = live(conn, ~p"/saved-queries")
      assert html =~ "Sales Report"
      assert html =~ "analytics-db"
    end

    test "filters by search term", %{conn: conn, scope: scope} do
      ds = data_source_fixture(scope)
      saved_query_fixture(scope, ds, %{title: "Sales Report"})
      saved_query_fixture(scope, ds, %{title: "User Activity"})

      {:ok, lv, _html} = live(conn, ~p"/saved-queries")

      html =
        lv
        |> form("form", %{search: "sales"})
        |> render_change()

      assert html =~ "Sales Report"
      refute html =~ "User Activity"
    end

    test "filters by favorites", %{conn: conn, scope: scope} do
      ds = data_source_fixture(scope)
      saved_query_fixture(scope, ds, %{title: "Favorite Query", is_favorite: true})
      saved_query_fixture(scope, ds, %{title: "Normal Query", is_favorite: false})

      {:ok, lv, _html} = live(conn, ~p"/saved-queries")

      html =
        lv
        |> form("form", %{favorites: "true"})
        |> render_change()

      assert html =~ "Favorite Query"
      refute html =~ "Normal Query"
    end

    test "filters by data source", %{conn: conn, scope: scope} do
      ds1 = data_source_fixture(scope, %{name: "db-one"})
      ds2 = data_source_fixture(scope, %{name: "db-two"})
      saved_query_fixture(scope, ds1, %{title: "DS1 Query"})
      saved_query_fixture(scope, ds2, %{title: "DS2 Query"})

      {:ok, lv, _html} = live(conn, ~p"/saved-queries")

      html =
        lv
        |> form("form", %{data_source_id: ds1.id})
        |> render_change()

      assert html =~ "DS1 Query"
      refute html =~ "DS2 Query"
    end

    test "toggles favorite", %{conn: conn, scope: scope} do
      ds = data_source_fixture(scope)
      sq = saved_query_fixture(scope, ds, %{title: "Toggle Me", is_favorite: false})

      {:ok, lv, html} = live(conn, ~p"/saved-queries")
      assert html =~ "hero-star"
      refute html =~ "hero-star-solid"

      html = render_click(lv, "toggle_favorite", %{id: sq.id})
      assert html =~ "hero-star-solid"
    end

    test "deletes a saved query", %{conn: conn, scope: scope} do
      ds = data_source_fixture(scope)
      sq = saved_query_fixture(scope, ds, %{title: "Delete Me"})

      {:ok, lv, html} = live(conn, ~p"/saved-queries")
      assert html =~ "Delete Me"

      html = render_click(lv, "delete", %{id: sq.id})
      refute html =~ "Delete Me"
    end

    test "has Open in Editor link", %{conn: conn, scope: scope} do
      ds = data_source_fixture(scope)
      sq = saved_query_fixture(scope, ds, %{title: "Openable"})

      {:ok, _lv, html} = live(conn, ~p"/saved-queries")
      assert html =~ "Open in Editor"
      assert html =~ "/sql-editor?saved_query_id=#{sq.id}"
    end
  end

  describe "unauthenticated access" do
    test "redirects to login", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/saved-queries")
      assert {:redirect, %{to: path}} = redirect
      assert path =~ ~p"/users/log-in"
    end
  end
end
