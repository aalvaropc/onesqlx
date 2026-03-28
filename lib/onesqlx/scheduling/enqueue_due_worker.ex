defmodule Onesqlx.Scheduling.EnqueueDueWorker do
  @moduledoc """
  Oban worker that checks for due scheduled queries and enqueues execution jobs.

  Runs every minute via Oban.Plugins.Cron. Queries for enabled scheduled queries
  whose `next_run_at` is in the past and enqueues an `ExecuteWorker` for each.
  """

  use Oban.Worker, queue: :scheduled_queries, max_attempts: 1, unique: [period: 60]

  alias Onesqlx.Scheduling
  alias Onesqlx.Scheduling.ExecuteWorker

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    due_queries = Scheduling.list_due_queries()

    Enum.each(due_queries, fn sq ->
      ExecuteWorker.enqueue(sq.id)
    end)

    :ok
  end
end
