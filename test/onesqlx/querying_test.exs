defmodule Onesqlx.QueryingTest do
  use Onesqlx.DataCase, async: true

  alias Onesqlx.Querying

  import Onesqlx.AccountsFixtures
  import Onesqlx.DataSourcesFixtures
  import Onesqlx.QueryingFixtures

  setup do
    scope = user_scope_fixture()
    data_source = data_source_fixture(scope)
    %{scope: scope, data_source: data_source}
  end

  describe "record_query_run/2" do
    test "creates a query run with valid attributes", %{scope: scope, data_source: data_source} do
      attrs = valid_query_run_attributes(scope, data_source)

      assert {:ok, run} = Querying.record_query_run(scope, attrs)
      assert run.sql == "SELECT 1"
      assert run.status == "success"
      assert run.duration_ms == 42
      assert run.row_count == 1
      assert run.workspace_id == scope.workspace.id
      assert run.user_id == scope.user.id
      assert run.data_source_id == data_source.id
    end

    test "rejects invalid status", %{scope: scope, data_source: data_source} do
      attrs = valid_query_run_attributes(scope, data_source, %{status: "invalid"})

      assert {:error, changeset} = Querying.record_query_run(scope, attrs)
      assert errors_on(changeset).status
    end

    test "requires sql, status, and executed_at", %{scope: scope} do
      assert {:error, changeset} = Querying.record_query_run(scope, %{})
      errors = errors_on(changeset)
      assert errors.sql
      assert errors.status
      assert errors.executed_at
    end
  end

  describe "list_recent_runs/3" do
    test "returns runs ordered by executed_at desc", %{scope: scope, data_source: data_source} do
      t1 = ~U[2026-03-01 10:00:00Z]
      t2 = ~U[2026-03-01 11:00:00Z]
      t3 = ~U[2026-03-01 12:00:00Z]

      _run1 = query_run_fixture(scope, data_source, %{sql: "SELECT 1", executed_at: t1})
      _run2 = query_run_fixture(scope, data_source, %{sql: "SELECT 2", executed_at: t3})
      _run3 = query_run_fixture(scope, data_source, %{sql: "SELECT 3", executed_at: t2})

      runs = Querying.list_recent_runs(scope, data_source.id)
      assert length(runs) == 3
      assert Enum.map(runs, & &1.sql) == ["SELECT 2", "SELECT 3", "SELECT 1"]
    end

    test "respects limit option", %{scope: scope, data_source: data_source} do
      for i <- 1..5 do
        query_run_fixture(scope, data_source, %{
          sql: "SELECT #{i}",
          executed_at: DateTime.add(~U[2026-03-01 10:00:00Z], i, :second)
        })
      end

      runs = Querying.list_recent_runs(scope, data_source.id, limit: 3)
      assert length(runs) == 3
    end

    test "filters by data_source_id", %{scope: scope, data_source: data_source} do
      other_ds = data_source_fixture(scope, %{name: "other-ds"})

      query_run_fixture(scope, data_source, %{sql: "SELECT 1"})
      query_run_fixture(scope, other_ds, %{sql: "SELECT 2"})

      runs = Querying.list_recent_runs(scope, data_source.id)
      assert length(runs) == 1
      assert hd(runs).sql == "SELECT 1"
    end

    test "enforces workspace isolation", %{scope: scope, data_source: data_source} do
      other_scope = user_scope_fixture()
      other_ds = data_source_fixture(other_scope, %{name: "other-ds"})

      query_run_fixture(scope, data_source, %{sql: "SELECT 1"})
      query_run_fixture(other_scope, other_ds, %{sql: "SELECT 2"})

      runs = Querying.list_recent_runs(scope, data_source.id)
      assert length(runs) == 1
      assert hd(runs).sql == "SELECT 1"
    end
  end

  describe "get_query_run!/2" do
    test "returns the query run scoped to workspace", %{scope: scope, data_source: data_source} do
      run = query_run_fixture(scope, data_source)
      found = Querying.get_query_run!(scope, run.id)
      assert found.id == run.id
    end

    test "raises for run in different workspace", %{data_source: data_source, scope: scope} do
      run = query_run_fixture(scope, data_source)
      other_scope = user_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Querying.get_query_run!(other_scope, run.id)
      end
    end
  end
end
