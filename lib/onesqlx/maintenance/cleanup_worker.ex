defmodule Onesqlx.Maintenance.CleanupWorker do
  @moduledoc """
  Oban worker that performs periodic data cleanup.

  Runs daily at 3 AM via Oban.Plugins.Cron. Removes old query runs,
  audit events, scheduled query runs, and expired API tokens according
  to the retention policies in the `:onesqlx, :retention` config
  (overridable with `RETENTION_*` env vars in production).
  """

  use Oban.Worker, queue: :maintenance, max_attempts: 1

  import Ecto.Query

  alias Onesqlx.Accounts.ApiToken
  alias Onesqlx.Audit.AuditEvent
  alias Onesqlx.Querying.QueryRun
  alias Onesqlx.Repo
  alias Onesqlx.Scheduling.ScheduledQueryRun

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    cleanup_old_query_runs()
    cleanup_old_audit_events()
    cleanup_old_scheduled_query_runs()
    cleanup_expired_api_tokens()
    :ok
  end

  defp cleanup_old_query_runs do
    cutoff = cutoff_for(:query_runs_days)

    QueryRun
    |> where([r], r.inserted_at < ^cutoff)
    |> Repo.delete_all()
  end

  defp cleanup_old_audit_events do
    cutoff = cutoff_for(:audit_events_days)

    AuditEvent
    |> where([e], e.occurred_at < ^cutoff)
    |> Repo.delete_all()
  end

  defp cleanup_old_scheduled_query_runs do
    cutoff = cutoff_for(:scheduled_runs_days)

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

  defp cutoff_for(key) do
    days = Application.fetch_env!(:onesqlx, :retention)[key]
    DateTime.add(DateTime.utc_now(:second), -days * 86_400, :second)
  end
end
