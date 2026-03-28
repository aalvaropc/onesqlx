defmodule Onesqlx.AuditTest do
  use Onesqlx.DataCase, async: true

  alias Onesqlx.Audit

  import Onesqlx.AccountsFixtures
  import Onesqlx.AuditFixtures
  import Onesqlx.DataSourcesFixtures
  import Onesqlx.QueryingFixtures

  setup do
    scope = user_scope_fixture()
    %{scope: scope}
  end

  describe "record_event/3" do
    test "creates event with correct fields", %{scope: scope} do
      {:ok, event} =
        Audit.record_event(scope, "query.executed", %{
          resource_type: "data_source",
          resource_id: Ecto.UUID.generate(),
          metadata: %{sql_preview: "SELECT 1"}
        })

      assert event.event_type == "query.executed"
      assert event.workspace_id == scope.workspace.id
      assert event.user_id == scope.user.id
      assert event.resource_type == "data_source"
      assert event.metadata == %{sql_preview: "SELECT 1"}
      assert event.occurred_at != nil
    end

    test "creates event with minimal attrs", %{scope: scope} do
      {:ok, event} = Audit.record_event(scope, "user.login")
      assert event.event_type == "user.login"
      assert event.metadata == %{}
    end
  end

  describe "list_events/2" do
    test "returns events ordered by occurred_at desc", %{scope: scope} do
      e1 = audit_event_fixture(scope, "query.executed")
      past = DateTime.add(DateTime.utc_now(:second), -60, :second)

      Repo.update_all(
        from(e in Onesqlx.Audit.AuditEvent, where: e.id == ^e1.id),
        set: [occurred_at: past]
      )

      _e2 = audit_event_fixture(scope, "query.saved")

      events = Audit.list_events(scope)
      assert length(events) == 2
      assert hd(events).event_type == "query.saved"
    end

    test "filters by event_type", %{scope: scope} do
      audit_event_fixture(scope, "query.executed")
      audit_event_fixture(scope, "dashboard.created")

      events = Audit.list_events(scope, event_type: "query.executed")
      assert length(events) == 1
      assert hd(events).event_type == "query.executed"
    end

    test "filters by resource_type", %{scope: scope} do
      audit_event_fixture(scope, "query.executed", %{resource_type: "data_source"})
      audit_event_fixture(scope, "query.executed", %{resource_type: "dashboard"})

      events = Audit.list_events(scope, resource_type: "data_source")
      assert length(events) == 1
    end

    test "filters by since", %{scope: scope} do
      e1 = audit_event_fixture(scope, "old.event")
      past = DateTime.add(DateTime.utc_now(:second), -3600, :second)

      Repo.update_all(
        from(e in Onesqlx.Audit.AuditEvent, where: e.id == ^e1.id),
        set: [occurred_at: past]
      )

      _e2 = audit_event_fixture(scope, "new.event")

      since = DateTime.add(DateTime.utc_now(:second), -60, :second)
      events = Audit.list_events(scope, since: since)
      assert length(events) == 1
      assert hd(events).event_type == "new.event"
    end

    test "respects limit", %{scope: scope} do
      for _ <- 1..5, do: audit_event_fixture(scope, "event")
      events = Audit.list_events(scope, limit: 3)
      assert length(events) == 3
    end

    test "enforces workspace isolation", %{scope: scope} do
      audit_event_fixture(scope, "visible.event")
      other_scope = user_scope_fixture()
      assert Audit.list_events(other_scope) == []
    end

    test "preloads user", %{scope: scope} do
      audit_event_fixture(scope, "query.executed")
      [event] = Audit.list_events(scope)
      assert event.user.id == scope.user.id
    end
  end

  describe "count_events/2" do
    test "returns correct count", %{scope: scope} do
      for _ <- 1..3, do: audit_event_fixture(scope, "query.executed")
      assert Audit.count_events(scope) == 3
    end

    test "filters by event_type", %{scope: scope} do
      audit_event_fixture(scope, "query.executed")
      audit_event_fixture(scope, "dashboard.created")
      assert Audit.count_events(scope, event_type: "query.executed") == 1
    end
  end

  describe "query_execution_stats/2" do
    test "returns correct aggregation", %{scope: scope} do
      data_source = data_source_fixture(scope)
      query_run_fixture(scope, data_source, %{status: "success", duration_ms: 100})
      query_run_fixture(scope, data_source, %{status: "success", duration_ms: 200})
      query_run_fixture(scope, data_source, %{status: "error", duration_ms: 50})

      stats = Audit.query_execution_stats(scope)
      assert stats.total_executions == 3
      assert stats.successful == 2
      assert stats.failed == 1
      assert stats.avg_duration_ms > 0
    end

    test "returns zeros when no runs", %{scope: scope} do
      stats = Audit.query_execution_stats(scope)
      assert stats.total_executions == 0
      assert stats.successful == 0
      assert stats.failed == 0
      assert stats.avg_duration_ms == 0
    end
  end

  describe "most_active_users/2" do
    test "returns users ranked by event count", %{scope: scope} do
      for _ <- 1..3, do: audit_event_fixture(scope, "query.executed")

      result = Audit.most_active_users(scope)
      assert [{email, 3}] = result
      assert email == scope.user.email
    end

    test "respects limit", %{scope: scope} do
      audit_event_fixture(scope, "event")
      result = Audit.most_active_users(scope, limit: 1)
      assert length(result) == 1
    end
  end

  describe "slowest_queries/2" do
    test "returns runs ordered by duration desc", %{scope: scope} do
      data_source = data_source_fixture(scope)
      query_run_fixture(scope, data_source, %{status: "success", duration_ms: 50})
      query_run_fixture(scope, data_source, %{status: "success", duration_ms: 500})
      query_run_fixture(scope, data_source, %{status: "success", duration_ms: 200})

      runs = Audit.slowest_queries(scope, limit: 2)
      assert length(runs) == 2
      assert hd(runs).duration_ms == 500
    end
  end
end
