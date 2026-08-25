defmodule Onesqlx.SearchTest do
  use Onesqlx.DataCase, async: true

  import Onesqlx.AccountsFixtures
  import Onesqlx.DashboardsFixtures
  import Onesqlx.DataSourcesFixtures
  import Onesqlx.SavedQueriesFixtures

  alias Onesqlx.Search

  setup do
    scope = user_scope_fixture()
    %{scope: scope, data_source: data_source_fixture(scope)}
  end

  describe "search/2" do
    test "matches saved queries by title", %{scope: scope, data_source: ds} do
      saved_query_fixture(scope, ds, %{title: "Monthly revenue", sql: "SELECT 1"})

      assert %{saved_queries: [%{title: "Monthly revenue", snippet: nil}]} =
               Search.search(scope, "revenue")
    end

    test "matches inside the SQL body with a context snippet", %{scope: scope, data_source: ds} do
      saved_query_fixture(scope, ds, %{
        title: "Q3 report",
        sql: "SELECT *\nFROM payments\nWHERE status = 'paid'"
      })

      assert %{saved_queries: [result]} = Search.search(scope, "payments")
      assert result.title == "Q3 report"
      assert result.snippet == "FROM payments"
    end

    test "matches the description with a snippet", %{scope: scope, data_source: ds} do
      saved_query_fixture(scope, ds, %{
        title: "Untitled",
        description: "Tracks churn cohorts weekly",
        sql: "SELECT 1"
      })

      assert %{saved_queries: [%{snippet: "Tracks churn cohorts weekly"}]} =
               Search.search(scope, "churn")
    end

    test "long snippet lines are truncated", %{scope: scope, data_source: ds} do
      long_line = "SELECT " <> String.duplicate("column_name, ", 20) <> "1 FROM payments"
      saved_query_fixture(scope, ds, %{title: "Wide", sql: long_line})

      assert %{saved_queries: [%{snippet: snippet}]} = Search.search(scope, "payments")
      assert String.ends_with?(snippet, "…")
      assert String.length(snippet) == 81
    end

    test "matches dashboards, and other types by name", %{scope: scope} do
      dashboard_fixture(scope, %{title: "Ops overview"})

      assert %{dashboards: [%{title: "Ops overview"}]} = Search.search(scope, "ops")
    end

    test "is isolated per workspace", %{scope: scope, data_source: ds} do
      saved_query_fixture(scope, ds, %{title: "Secret metrics", sql: "SELECT 1"})
      other_scope = user_scope_fixture()

      assert %{saved_queries: []} = Search.search(other_scope, "secret")
    end

    test "SQL wildcards in the term are literal, not wildcards", %{scope: scope, data_source: ds} do
      saved_query_fixture(scope, ds, %{title: "Percent % of total", sql: "SELECT 1"})
      saved_query_fixture(scope, ds, %{title: "Unrelated", sql: "SELECT 2"})

      # "%" must match only the title containing a literal percent sign
      assert %{saved_queries: [%{title: "Percent % of total"}]} = Search.search(scope, "%")
      # same for underscore
      assert %{saved_queries: []} = Search.search(scope, "_related_")
    end

    test "empty query returns empty groups", %{scope: scope} do
      assert %{saved_queries: [], dashboards: [], schedules: [], data_sources: []} =
               Search.search(scope, "")
    end

    test "caps results per type at five", %{scope: scope, data_source: ds} do
      for i <- 1..7 do
        saved_query_fixture(scope, ds, %{title: "batch query #{i}", sql: "SELECT #{i}"})
      end

      assert %{saved_queries: results} = Search.search(scope, "batch")
      assert length(results) == 5
    end
  end
end
