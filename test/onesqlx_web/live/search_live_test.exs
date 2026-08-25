defmodule OnesqlxWeb.SearchLiveTest do
  use OnesqlxWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Onesqlx.DataSourcesFixtures
  import Onesqlx.SavedQueriesFixtures

  setup :register_and_log_in_user

  test "shows results with a SQL context snippet", %{conn: conn, scope: scope} do
    ds = data_source_fixture(scope)

    saved_query_fixture(scope, ds, %{
      title: "Q3 report",
      sql: "SELECT *\nFROM payments\nWHERE paid"
    })

    {:ok, lv, _html} = live(conn, ~p"/search")
    html = render_change(lv, "search", %{"q" => "payments"})

    assert html =~ "Q3 report"
    assert html =~ "FROM payments"
  end

  test "shows the empty state for no matches", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/search")
    html = render_change(lv, "search", %{"q" => "zzz-nothing"})

    assert html =~ "No results found"
  end
end
