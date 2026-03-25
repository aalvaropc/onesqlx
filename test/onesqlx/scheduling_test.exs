defmodule Onesqlx.SchedulingTest do
  use Onesqlx.DataCase, async: true

  alias Onesqlx.Scheduling

  import Onesqlx.AccountsFixtures
  import Onesqlx.DataSourcesFixtures
  import Onesqlx.SavedQueriesFixtures
  import Onesqlx.SchedulingFixtures

  setup do
    scope = user_scope_fixture()
    data_source = data_source_fixture(scope)
    saved_query = saved_query_fixture(scope, data_source)
    %{scope: scope, data_source: data_source, saved_query: saved_query}
  end

  describe "create_scheduled_query/2" do
    test "creates with valid attributes", %{scope: scope, saved_query: saved_query} do
      attrs = valid_scheduled_query_attributes(saved_query, %{name: "Daily Report"})
      assert {:ok, sq} = Scheduling.create_scheduled_query(scope, attrs)
      assert sq.name == "Daily Report"
      assert sq.schedule_type == "daily"
      assert sq.workspace_id == scope.workspace.id
      assert sq.user_id == scope.user.id
      assert sq.enabled == true
      assert sq.next_run_at != nil
    end

    test "requires name and schedule_type", %{scope: scope} do
      assert {:error, changeset} = Scheduling.create_scheduled_query(scope, %{})
      errors = errors_on(changeset)
      assert errors.name
      assert errors.saved_query_id
    end

    test "enforces unique name per workspace", %{scope: scope, saved_query: saved_query} do
      scheduled_query_fixture(scope, saved_query, %{name: "Duplicate"})

      attrs = valid_scheduled_query_attributes(saved_query, %{name: "Duplicate"})
      assert {:error, changeset} = Scheduling.create_scheduled_query(scope, attrs)
      assert "has already been taken" in errors_on(changeset).name
    end

    test "allows same name in different workspaces", %{saved_query: saved_query, scope: scope} do
      scheduled_query_fixture(scope, saved_query, %{name: "Shared Name"})

      other_scope = user_scope_fixture()
      other_ds = data_source_fixture(other_scope)
      other_sq = saved_query_fixture(other_scope, other_ds)

      attrs = valid_scheduled_query_attributes(other_sq, %{name: "Shared Name"})
      assert {:ok, _} = Scheduling.create_scheduled_query(other_scope, attrs)
    end

    test "validates schedule_type inclusion", %{scope: scope, saved_query: saved_query} do
      attrs = valid_scheduled_query_attributes(saved_query, %{schedule_type: "biweekly"})
      assert {:error, changeset} = Scheduling.create_scheduled_query(scope, attrs)
      assert errors_on(changeset).schedule_type
    end

    test "cron type requires cron_expression", %{scope: scope, saved_query: saved_query} do
      attrs = valid_scheduled_query_attributes(saved_query, %{schedule_type: "cron"})
      assert {:error, changeset} = Scheduling.create_scheduled_query(scope, attrs)
      assert errors_on(changeset).cron_expression
    end

    test "cron type accepts valid expression", %{scope: scope, saved_query: saved_query} do
      attrs =
        valid_scheduled_query_attributes(saved_query, %{
          schedule_type: "cron",
          cron_expression: "0 * * * *"
        })

      assert {:ok, sq} = Scheduling.create_scheduled_query(scope, attrs)
      assert sq.cron_expression == "0 * * * *"
    end

    test "sets next_run_at when enabled", %{scope: scope, saved_query: saved_query} do
      attrs = valid_scheduled_query_attributes(saved_query, %{enabled: true})
      assert {:ok, sq} = Scheduling.create_scheduled_query(scope, attrs)
      assert sq.next_run_at != nil
    end

    test "clears next_run_at when disabled", %{scope: scope, saved_query: saved_query} do
      attrs = valid_scheduled_query_attributes(saved_query, %{enabled: false})
      assert {:ok, sq} = Scheduling.create_scheduled_query(scope, attrs)
      assert sq.next_run_at == nil
    end
  end

  describe "list_scheduled_queries/2" do
    test "returns queries ordered by name", %{scope: scope, saved_query: saved_query} do
      scheduled_query_fixture(scope, saved_query, %{name: "Zebra"})
      scheduled_query_fixture(scope, saved_query, %{name: "Alpha"})

      result = Scheduling.list_scheduled_queries(scope)
      names = Enum.map(result, & &1.name)
      assert names == ["Alpha", "Zebra"]
    end

    test "enforces workspace isolation", %{scope: scope, saved_query: saved_query} do
      scheduled_query_fixture(scope, saved_query, %{name: "Visible"})

      other_scope = user_scope_fixture()
      assert Scheduling.list_scheduled_queries(other_scope) == []
    end

    test "filters by enabled_only", %{scope: scope, saved_query: saved_query} do
      scheduled_query_fixture(scope, saved_query, %{name: "Active", enabled: true})
      scheduled_query_fixture(scope, saved_query, %{name: "Inactive", enabled: false})

      result = Scheduling.list_scheduled_queries(scope, enabled_only: true)
      assert length(result) == 1
      assert hd(result).name == "Active"
    end

    test "filters by saved_query_id", %{scope: scope, data_source: data_source, saved_query: sq1} do
      sq2 = saved_query_fixture(scope, data_source, %{title: "Other Query"})

      scheduled_query_fixture(scope, sq1, %{name: "For SQ1"})
      scheduled_query_fixture(scope, sq2, %{name: "For SQ2"})

      result = Scheduling.list_scheduled_queries(scope, saved_query_id: sq1.id)
      assert length(result) == 1
      assert hd(result).name == "For SQ1"
    end

    test "preloads saved_query", %{scope: scope, saved_query: saved_query} do
      scheduled_query_fixture(scope, saved_query)

      [sq] = Scheduling.list_scheduled_queries(scope)
      assert sq.saved_query.id == saved_query.id
    end
  end

  describe "get_scheduled_query!/2" do
    test "returns scoped to workspace", %{scope: scope, saved_query: saved_query} do
      sq = scheduled_query_fixture(scope, saved_query)
      found = Scheduling.get_scheduled_query!(scope, sq.id)
      assert found.id == sq.id
    end

    test "raises for different workspace", %{scope: scope, saved_query: saved_query} do
      sq = scheduled_query_fixture(scope, saved_query)
      other_scope = user_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Scheduling.get_scheduled_query!(other_scope, sq.id)
      end
    end

    test "preloads saved_query with data_source", %{
      scope: scope,
      saved_query: saved_query,
      data_source: data_source
    } do
      sq = scheduled_query_fixture(scope, saved_query)
      found = Scheduling.get_scheduled_query!(scope, sq.id)
      assert found.saved_query.id == saved_query.id
      assert found.saved_query.data_source.id == data_source.id
    end
  end

  describe "update_scheduled_query/3" do
    test "updates name and schedule_type", %{scope: scope, saved_query: saved_query} do
      sq = scheduled_query_fixture(scope, saved_query)

      assert {:ok, updated} =
               Scheduling.update_scheduled_query(scope, sq, %{
                 name: "Updated",
                 schedule_type: "hourly"
               })

      assert updated.name == "Updated"
      assert updated.schedule_type == "hourly"
    end

    test "rejects blank name", %{scope: scope, saved_query: saved_query} do
      sq = scheduled_query_fixture(scope, saved_query)
      assert {:error, changeset} = Scheduling.update_scheduled_query(scope, sq, %{name: ""})
      assert errors_on(changeset).name
    end
  end

  describe "delete_scheduled_query/2" do
    test "deletes the scheduled query", %{scope: scope, saved_query: saved_query} do
      sq = scheduled_query_fixture(scope, saved_query)
      assert {:ok, _} = Scheduling.delete_scheduled_query(scope, sq)

      assert_raise Ecto.NoResultsError, fn ->
        Scheduling.get_scheduled_query!(scope, sq.id)
      end
    end
  end

  describe "toggle_enabled/2" do
    test "disabling clears next_run_at", %{scope: scope, saved_query: saved_query} do
      sq = scheduled_query_fixture(scope, saved_query, %{enabled: true})
      assert sq.next_run_at != nil

      {:ok, disabled} = Scheduling.toggle_enabled(scope, sq)
      assert disabled.enabled == false
      assert disabled.next_run_at == nil
    end

    test "enabling sets next_run_at", %{scope: scope, saved_query: saved_query} do
      sq = scheduled_query_fixture(scope, saved_query, %{enabled: false})
      assert sq.next_run_at == nil

      {:ok, enabled} = Scheduling.toggle_enabled(scope, sq)
      assert enabled.enabled == true
      assert enabled.next_run_at != nil
    end
  end

  describe "list_runs/3" do
    test "returns runs ordered by started_at desc", %{scope: scope, saved_query: saved_query} do
      sq = scheduled_query_fixture(scope, saved_query)
      now = DateTime.utc_now(:second)
      earlier = DateTime.add(now, -60, :second)

      {:ok, _} = Scheduling.record_run(sq, %{status: "success", started_at: earlier})
      {:ok, _} = Scheduling.record_run(sq, %{status: "error", started_at: now})

      runs = Scheduling.list_runs(scope, sq.id)
      assert length(runs) == 2
      assert hd(runs).status == "error"
    end

    test "respects limit", %{scope: scope, saved_query: saved_query} do
      sq = scheduled_query_fixture(scope, saved_query)
      now = DateTime.utc_now(:second)

      for i <- 1..5 do
        {:ok, _} =
          Scheduling.record_run(sq, %{
            status: "success",
            started_at: DateTime.add(now, i, :second)
          })
      end

      assert length(Scheduling.list_runs(scope, sq.id, limit: 3)) == 3
    end
  end

  describe "record_run/2" do
    test "creates run and updates parent timestamps", %{scope: scope, saved_query: saved_query} do
      sq = scheduled_query_fixture(scope, saved_query)
      assert sq.last_run_at == nil

      {:ok, run} =
        Scheduling.record_run(sq, %{
          status: "success",
          started_at: DateTime.utc_now(:second),
          duration_ms: 150,
          row_count: 10
        })

      assert run.status == "success"
      assert run.scheduled_query_id == sq.id

      updated_sq = Scheduling.get_scheduled_query!(scope, sq.id)
      assert updated_sq.last_run_at != nil
      assert updated_sq.next_run_at != nil
    end
  end

  describe "list_due_queries/0" do
    test "returns enabled queries with past next_run_at", %{
      scope: scope,
      saved_query: saved_query
    } do
      sq = scheduled_query_fixture(scope, saved_query, %{enabled: true})

      # Force next_run_at to the past
      past = DateTime.add(DateTime.utc_now(:second), -60, :second)

      Repo.update_all(
        from(s in Onesqlx.Scheduling.ScheduledQuery, where: s.id == ^sq.id),
        set: [next_run_at: past]
      )

      due = Scheduling.list_due_queries()
      assert length(due) == 1
      assert hd(due).id == sq.id
    end

    test "excludes disabled queries", %{scope: scope, saved_query: saved_query} do
      sq = scheduled_query_fixture(scope, saved_query, %{enabled: false})
      past = DateTime.add(DateTime.utc_now(:second), -60, :second)

      Repo.update_all(
        from(s in Onesqlx.Scheduling.ScheduledQuery, where: s.id == ^sq.id),
        set: [next_run_at: past, enabled: true]
      )

      # Now disable it
      Repo.update_all(
        from(s in Onesqlx.Scheduling.ScheduledQuery, where: s.id == ^sq.id),
        set: [enabled: false]
      )

      assert Scheduling.list_due_queries() == []
    end

    test "excludes queries with future next_run_at", %{scope: scope, saved_query: saved_query} do
      _sq = scheduled_query_fixture(scope, saved_query, %{enabled: true})
      # next_run_at is set to the future by default
      assert Scheduling.list_due_queries() == []
    end
  end

  describe "change_scheduled_query/2" do
    test "returns a changeset" do
      changeset = Scheduling.change_scheduled_query(%Onesqlx.Scheduling.ScheduledQuery{})
      assert %Ecto.Changeset{} = changeset
    end
  end
end
