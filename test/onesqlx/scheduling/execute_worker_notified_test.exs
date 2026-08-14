defmodule Onesqlx.Scheduling.ExecuteWorkerNotifiedTest do
  use Onesqlx.DataCase, async: true
  use Oban.Testing, repo: Onesqlx.Repo

  import Mox
  import Onesqlx.AccountsFixtures
  import Onesqlx.DataSourcesFixtures
  import Onesqlx.SavedQueriesFixtures
  import Onesqlx.SchedulingFixtures
  import Swoosh.TestAssertions

  alias Onesqlx.DataSources.MockConnection
  alias Onesqlx.Scheduling
  alias Onesqlx.Scheduling.ExecuteWorker

  setup :verify_on_exit!

  setup do
    scope = user_scope_fixture()
    data_source = data_source_fixture(scope)
    saved_query = saved_query_fixture(scope, data_source)

    # The user fixture delivers a confirmation email; drop it so the
    # mailbox assertions below only see run notifications.
    drain_emails()

    %{scope: scope, saved_query: saved_query}
  end

  defp drain_emails do
    receive do
      {:email, _} -> drain_emails()
    after
      0 -> :ok
    end
  end

  defp stub_result(row_count) do
    stub(MockConnection, :with_connection, fn _ds, _fun ->
      {:ok,
       %{
         columns: ["n"],
         rows: [[row_count]],
         row_count: row_count,
         duration_ms: 5
       }}
    end)
  end

  test "records notified: true when the condition holds and email is set", %{
    scope: scope,
    saved_query: saved_query
  } do
    sq =
      scheduled_query_fixture(scope, saved_query, %{
        notify_email: "ops@example.com",
        alert_condition: "row_count_lt",
        alert_threshold: 10
      })

    stub_result(3)

    assert :ok = perform_job(ExecuteWorker, %{"scheduled_query_id" => sq.id})

    [run] = Scheduling.list_runs(scope, sq.id)
    assert run.notified
    assert_email_sent(fn email -> email.subject =~ sq.name end)
  end

  test "records notified: false when the condition does not hold", %{
    scope: scope,
    saved_query: saved_query
  } do
    sq =
      scheduled_query_fixture(scope, saved_query, %{
        notify_email: "ops@example.com",
        alert_condition: "row_count_lt",
        alert_threshold: 10
      })

    stub_result(50)

    assert :ok = perform_job(ExecuteWorker, %{"scheduled_query_id" => sq.id})

    [run] = Scheduling.list_runs(scope, sq.id)
    refute run.notified
    refute_email_sent()
  end

  test "records notified: false with no notification channel even if condition holds", %{
    scope: scope,
    saved_query: saved_query
  } do
    sq =
      scheduled_query_fixture(scope, saved_query, %{
        alert_condition: "row_count_lt",
        alert_threshold: 10
      })

    stub_result(3)

    assert :ok = perform_job(ExecuteWorker, %{"scheduled_query_id" => sq.id})

    [run] = Scheduling.list_runs(scope, sq.id)
    refute run.notified
  end
end
