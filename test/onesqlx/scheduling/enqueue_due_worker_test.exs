defmodule Onesqlx.Scheduling.EnqueueDueWorkerTest do
  use Onesqlx.DataCase, async: true
  use Oban.Testing, repo: Onesqlx.Repo

  import Onesqlx.AccountsFixtures
  import Onesqlx.DataSourcesFixtures
  import Onesqlx.SavedQueriesFixtures
  import Onesqlx.SchedulingFixtures

  alias Onesqlx.Scheduling.EnqueueDueWorker
  alias Onesqlx.Scheduling.ExecuteWorker
  alias Onesqlx.Scheduling.ScheduledQuery

  setup do
    scope = user_scope_fixture()
    data_source = data_source_fixture(scope)
    saved_query = saved_query_fixture(scope, data_source)
    %{scope: scope, saved_query: saved_query}
  end

  describe "perform/1" do
    test "enqueues ExecuteWorker for due queries", %{scope: scope, saved_query: saved_query} do
      sq = scheduled_query_fixture(scope, saved_query, %{enabled: true})

      past = DateTime.add(DateTime.utc_now(:second), -120, :second)

      Repo.update_all(
        from(s in ScheduledQuery, where: s.id == ^sq.id),
        set: [next_run_at: past]
      )

      assert :ok = perform_job(EnqueueDueWorker, %{})

      assert_enqueued(worker: ExecuteWorker, args: %{"scheduled_query_id" => sq.id})
    end

    test "does not enqueue for disabled queries", %{scope: scope, saved_query: saved_query} do
      sq = scheduled_query_fixture(scope, saved_query, %{enabled: false})

      past = DateTime.add(DateTime.utc_now(:second), -120, :second)

      Repo.update_all(
        from(s in ScheduledQuery, where: s.id == ^sq.id),
        set: [next_run_at: past, enabled: false]
      )

      assert :ok = perform_job(EnqueueDueWorker, %{})

      refute_enqueued(worker: ExecuteWorker)
    end

    test "does not enqueue for future queries", %{scope: scope, saved_query: saved_query} do
      _sq = scheduled_query_fixture(scope, saved_query, %{enabled: true})
      # next_run_at is in the future by default

      assert :ok = perform_job(EnqueueDueWorker, %{})

      refute_enqueued(worker: ExecuteWorker)
    end

    test "completes without error when no due queries exist" do
      assert :ok = perform_job(EnqueueDueWorker, %{})
    end
  end
end
