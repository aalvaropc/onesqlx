defmodule Onesqlx.Maintenance.CleanupWorkerTest do
  use Onesqlx.DataCase, async: true
  use Oban.Testing, repo: Onesqlx.Repo

  import Onesqlx.AccountsFixtures
  import Onesqlx.AuditFixtures
  import Onesqlx.DataSourcesFixtures
  import Onesqlx.QueryingFixtures
  import Onesqlx.SavedQueriesFixtures
  import Onesqlx.SchedulingFixtures

  alias Onesqlx.Accounts.ApiToken
  alias Onesqlx.Audit.AuditEvent
  alias Onesqlx.Maintenance.CleanupWorker
  alias Onesqlx.Querying.QueryRun
  alias Onesqlx.Scheduling
  alias Onesqlx.Scheduling.ScheduledQueryRun

  setup do
    scope = user_scope_fixture()
    data_source = data_source_fixture(scope)
    %{scope: scope, data_source: data_source}
  end

  describe "perform/1" do
    test "deletes old query runs, preserves recent ones", %{scope: scope, data_source: ds} do
      old_run = query_run_fixture(scope, ds)
      recent_run = query_run_fixture(scope, ds)

      old_date = DateTime.add(DateTime.utc_now(:second), -91 * 86_400, :second)

      Repo.update_all(
        from(r in QueryRun, where: r.id == ^old_run.id),
        set: [inserted_at: old_date]
      )

      assert :ok = perform_job(CleanupWorker, %{})

      assert Repo.get(QueryRun, recent_run.id)
      refute Repo.get(QueryRun, old_run.id)
    end

    test "deletes old audit events, preserves recent ones", %{scope: scope} do
      old_event = audit_event_fixture(scope, "old.event")
      recent_event = audit_event_fixture(scope, "recent.event")

      old_date = DateTime.add(DateTime.utc_now(:second), -181 * 86_400, :second)

      Repo.update_all(
        from(e in AuditEvent, where: e.id == ^old_event.id),
        set: [occurred_at: old_date]
      )

      assert :ok = perform_job(CleanupWorker, %{})

      assert Repo.get(AuditEvent, recent_event.id)
      refute Repo.get(AuditEvent, old_event.id)
    end

    test "deletes old scheduled query runs", %{scope: scope, data_source: ds} do
      sq = saved_query_fixture(scope, ds)
      sched = scheduled_query_fixture(scope, sq)

      {:ok, old_run} =
        Scheduling.record_run(sched, %{
          status: "success",
          started_at: DateTime.add(DateTime.utc_now(:second), -31 * 86_400, :second)
        })

      {:ok, recent_run} =
        Scheduling.record_run(sched, %{
          status: "success",
          started_at: DateTime.utc_now(:second)
        })

      assert :ok = perform_job(CleanupWorker, %{})

      assert Repo.get(ScheduledQueryRun, recent_run.id)
      refute Repo.get(ScheduledQueryRun, old_run.id)
    end

    test "deletes expired API tokens", %{scope: scope} do
      past = DateTime.add(DateTime.utc_now(:second), -3600, :second)

      {_raw, expired_token} =
        ApiToken.build_token(scope.user, scope.workspace, "expired")

      {:ok, expired} =
        expired_token |> ApiToken.changeset(%{expires_at: past}) |> Repo.insert()

      {_raw2, valid_token} =
        ApiToken.build_token(scope.user, scope.workspace, "valid")

      {:ok, valid} =
        valid_token |> ApiToken.changeset(%{}) |> Repo.insert()

      assert :ok = perform_job(CleanupWorker, %{})

      refute Repo.get(ApiToken, expired.id)
      assert Repo.get(ApiToken, valid.id)
    end

    test "completes without error on empty tables" do
      assert :ok = perform_job(CleanupWorker, %{})
    end
  end
end
