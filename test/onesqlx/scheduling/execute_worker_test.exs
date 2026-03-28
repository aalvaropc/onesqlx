defmodule Onesqlx.Scheduling.ExecuteWorkerTest do
  use Onesqlx.DataCase, async: true
  use Oban.Testing, repo: Onesqlx.Repo

  import Mox
  import Onesqlx.AccountsFixtures
  import Onesqlx.DataSourcesFixtures
  import Onesqlx.SavedQueriesFixtures
  import Onesqlx.SchedulingFixtures

  alias Onesqlx.DataSources.MockConnection
  alias Onesqlx.Scheduling
  alias Onesqlx.Scheduling.ExecuteWorker

  setup :verify_on_exit!

  setup do
    scope = user_scope_fixture()
    data_source = data_source_fixture(scope)
    saved_query = saved_query_fixture(scope, data_source)
    scheduled_query = scheduled_query_fixture(scope, saved_query)

    %{
      scope: scope,
      data_source: data_source,
      saved_query: saved_query,
      scheduled_query: scheduled_query
    }
  end

  describe "perform/1" do
    test "successful execution creates run with result", %{
      scope: scope,
      scheduled_query: sq
    } do
      stub(MockConnection, :with_connection, fn _ds, _fun ->
        {:ok,
         %{
           columns: ["id", "name"],
           rows: [[1, "alice"], [2, "bob"]],
           row_count: 2,
           duration_ms: 42
         }}
      end)

      assert :ok = perform_job(ExecuteWorker, %{"scheduled_query_id" => sq.id})

      [run] = Scheduling.list_runs(scope, sq.id)
      assert run.status == "success"
      assert run.row_count == 2
      assert run.duration_ms == 42
      assert run.result_columns == ["id", "name"]
      assert run.result_rows == %{"rows" => [[1, "alice"], [2, "bob"]]}
      assert run.error_message == nil
    end

    test "failed execution creates run with error", %{
      scope: scope,
      scheduled_query: sq
    } do
      stub(MockConnection, :with_connection, fn _ds, _fun ->
        {:error, :execution, "relation \"missing_table\" does not exist"}
      end)

      assert :ok = perform_job(ExecuteWorker, %{"scheduled_query_id" => sq.id})

      [run] = Scheduling.list_runs(scope, sq.id)
      assert run.status == "error"
      assert run.error_message =~ "missing_table"
    end

    test "timeout creates run with timeout status", %{
      scope: scope,
      scheduled_query: sq
    } do
      stub(MockConnection, :with_connection, fn _ds, _fun ->
        {:error, :timeout, "statement timeout"}
      end)

      assert :ok = perform_job(ExecuteWorker, %{"scheduled_query_id" => sq.id})

      [run] = Scheduling.list_runs(scope, sq.id)
      assert run.status == "timeout"
      assert run.error_message =~ "timeout"
    end

    test "truncates result rows to 100", %{
      scope: scope,
      scheduled_query: sq
    } do
      large_rows = for i <- 1..200, do: [i, "row-#{i}"]

      stub(MockConnection, :with_connection, fn _ds, _fun ->
        {:ok,
         %{
           columns: ["id", "name"],
           rows: large_rows,
           row_count: 200,
           duration_ms: 100
         }}
      end)

      assert :ok = perform_job(ExecuteWorker, %{"scheduled_query_id" => sq.id})

      [run] = Scheduling.list_runs(scope, sq.id)
      assert run.status == "success"
      assert run.row_count == 200
      assert length(run.result_rows["rows"]) == 100
    end

    test "updates parent timestamps after execution", %{
      scope: scope,
      scheduled_query: sq
    } do
      assert sq.last_run_at == nil

      stub(MockConnection, :with_connection, fn _ds, _fun ->
        {:ok, %{columns: ["x"], rows: [[1]], row_count: 1, duration_ms: 5}}
      end)

      assert :ok = perform_job(ExecuteWorker, %{"scheduled_query_id" => sq.id})

      updated = Scheduling.get_scheduled_query!(scope, sq.id)
      assert updated.last_run_at != nil
      assert updated.next_run_at != nil
    end

    test "handles scheduled query with no data source", %{scope: scope} do
      # Create a saved query without data_source
      {:ok, sq_no_ds} =
        Onesqlx.SavedQueries.create_saved_query(scope, %{
          title: "no-ds-#{System.unique_integer([:positive])}",
          sql: "SELECT 1",
          user_id: scope.user.id
        })

      {:ok, sched} =
        Scheduling.create_scheduled_query(scope, %{
          name: "no-ds-schedule-#{System.unique_integer([:positive])}",
          schedule_type: "daily",
          saved_query_id: sq_no_ds.id
        })

      assert :ok = perform_job(ExecuteWorker, %{"scheduled_query_id" => sched.id})

      [run] = Scheduling.list_runs(scope, sched.id)
      assert run.status == "error"
      assert run.error_message =~ "No data source"
    end
  end

  describe "enqueue/1" do
    test "inserts an Oban job", %{scheduled_query: sq} do
      assert {:ok, _job} = ExecuteWorker.enqueue(sq.id)
      assert_enqueued(worker: ExecuteWorker, args: %{"scheduled_query_id" => sq.id})
    end
  end
end
