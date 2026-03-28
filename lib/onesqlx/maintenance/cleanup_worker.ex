defmodule Onesqlx.Maintenance.CleanupWorker do
  @moduledoc """
  Oban worker that performs periodic data cleanup.

  Runs daily at 3 AM via Oban.Plugins.Cron. Removes old query runs,
  audit events, scheduled query runs, and expired API tokens according
  to retention policies.
  """

  use Oban.Worker, queue: :maintenance, max_attempts: 1

  import Ecto.Query

  alias Onesqlx.Accounts.ApiToken
  alias Onesqlx.Audit.AuditEvent
  alias Onesqlx.Querying.QueryRun
  alias Onesqlx.Repo
  alias Onesqlx.Scheduling.ScheduledQueryRun

  @query_run_retention_days 90
  @audit_event_retention_days 180
  @scheduled_run_retention_days 30

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    cleanup_old_query_runs()
    cleanup_old_audit_events()
    cleanup_old_scheduled_query_runs()
    cleanup_expired_api_tokens()
    :ok
  end

  defp cleanup_old_query_runs do
    cutoff = DateTime.add(DateTime.utc_now(:second), -@query_run_retention_days * 86_400, :second)

    QueryRun
    |> where([r], r.inserted_at < ^cutoff)
    |> Repo.delete_all()
  end

  defp cleanup_old_audit_events do
    cutoff =
      DateTime.add(DateTime.utc_now(:second), -@audit_event_retention_days * 86_400, :second)

    AuditEvent
    |> where([e], e.occurred_at < ^cutoff)
    |> Repo.delete_all()
  end

  defp cleanup_old_scheduled_query_runs do
    cutoff =
      DateTime.add(DateTime.utc_now(:second), -@scheduled_run_retention_days * 86_400, :second)

    ScheduledQueryRun
    |> where([r], r.started_at < ^cutoff)
    |> Repo.delete_all()
  end

  defp cleanup_expired_api_tokens do
    now = DateTime.utc_now(:second)

    ApiToken
    |> where([t], not is_nil(t.expires_at) and t.expires_at < ^now)
    |> Repo.delete_all()
  end
end
