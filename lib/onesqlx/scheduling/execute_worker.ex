defmodule Onesqlx.Scheduling.ExecuteWorker do
  @moduledoc """
  Oban worker that executes a scheduled query and records the result.

  Invoked by `EnqueueDueWorker` for recurring schedules or manually via "Run Now".
  Transient errors (timeout, connection) are retried via Oban up to `max_retries`.
  Permanent errors (blocked SQL, execution errors) are recorded immediately.
  """

  use Oban.Worker, queue: :scheduled_queries, max_attempts: 4

  alias Onesqlx.Querying.Executor
  alias Onesqlx.Scheduling
  alias Onesqlx.Scheduling.AlertEvaluator
  alias Onesqlx.Scheduling.Notifier

  @max_stored_rows 100

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"scheduled_query_id" => id}, attempt: attempt, max_attempts: max}) do
    sq = Scheduling.get_scheduled_query_for_execution!(id)
    started_at = DateTime.utc_now(:second)
    last_attempt? = attempt >= max

    case execute_query(sq) do
      {:ok, run_attrs} ->
        finalize_run(sq, run_attrs, started_at)

      {:transient, run_attrs} when last_attempt? ->
        finalize_run(sq, run_attrs, started_at)

      {:transient, run_attrs} ->
        {:error, run_attrs.error_message}

      {:permanent, run_attrs} ->
        finalize_run(sq, run_attrs, started_at)
    end
  end

  @doc """
  Enqueues an execution job for the given scheduled query.

  Uses the query's `max_retries` to set Oban's `max_attempts`.
  """
  def enqueue(scheduled_query_id, max_retries \\ 3) do
    %{"scheduled_query_id" => scheduled_query_id}
    |> __MODULE__.new(max_attempts: max_retries + 1)
    |> Oban.insert()
  end

  defp execute_query(sq) do
    case {sq.saved_query, sq.saved_query && sq.saved_query.data_source} do
      {nil, _} ->
        {:permanent,
         %{
           status: "error",
           completed_at: DateTime.utc_now(:second),
           error_message: "No saved query assigned"
         }}

      {_, nil} ->
        {:permanent,
         %{
           status: "error",
           completed_at: DateTime.utc_now(:second),
           error_message: "No data source assigned to saved query"
         }}

      {saved_query, data_source} ->
        case Executor.execute(data_source, saved_query.sql, row_limit: @max_stored_rows) do
          {:ok, result} ->
            {:ok,
             %{
               status: "success",
               completed_at: DateTime.utc_now(:second),
               duration_ms: result.duration_ms,
               row_count: result.row_count,
               result_columns: result.columns,
               result_rows: %{"rows" => Enum.take(result.rows, @max_stored_rows)}
             }}

          {:error, :timeout, message} ->
            {:transient,
             %{status: "timeout", completed_at: DateTime.utc_now(:second), error_message: message}}

          {:error, :connection, message} ->
            {:transient,
             %{status: "error", completed_at: DateTime.utc_now(:second), error_message: message}}

          {:error, _type, message} ->
            {:permanent,
             %{status: "error", completed_at: DateTime.utc_now(:second), error_message: message}}
        end
    end
  end

  # Records the run (with whether an alert notification went out) and
  # dispatches the notifications when the alert condition holds.
  defp finalize_run(sq, run_attrs, started_at) do
    alert? = AlertEvaluator.should_alert?(sq, run_attrs)
    channel? = present?(sq.notify_email) or present?(Map.get(sq, :webhook_url))

    attrs =
      run_attrs
      |> Map.put(:started_at, started_at)
      |> Map.put(:notified, alert? and channel?)

    Scheduling.record_run(sq, attrs)

    if alert? do
      Notifier.deliver_run_result(sq, attrs)
      Notifier.deliver_webhook(sq, attrs)
    end

    :ok
  end

  defp present?(value), do: value not in [nil, ""]
end
