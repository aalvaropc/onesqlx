defmodule Onesqlx.Scheduling.ExecuteWorker do
  @moduledoc """
  Oban worker that executes a scheduled query and records the result.

  Invoked by `EnqueueDueWorker` for recurring schedules or manually via "Run Now".
  Always returns `:ok` to avoid retrying on query-level errors (SQL failures, timeouts).
  Oban retries are reserved for infrastructure errors (process crashes).
  """

  use Oban.Worker, queue: :scheduled_queries, max_attempts: 3

  alias Onesqlx.Querying.Executor
  alias Onesqlx.Scheduling

  @max_stored_rows 100

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"scheduled_query_id" => id}}) do
    sq = Scheduling.get_scheduled_query_for_execution!(id)
    started_at = DateTime.utc_now(:second)

    run_attrs = execute_and_build_attrs(sq, started_at)
    Scheduling.record_run(sq, run_attrs)

    :ok
  end

  @doc """
  Enqueues an execution job for the given scheduled query ID.
  """
  def enqueue(scheduled_query_id) do
    %{"scheduled_query_id" => scheduled_query_id}
    |> __MODULE__.new()
    |> Oban.insert()
  end

  defp execute_and_build_attrs(sq, started_at) do
    base = %{started_at: started_at}

    case {sq.saved_query, sq.saved_query && sq.saved_query.data_source} do
      {nil, _} ->
        Map.merge(base, %{
          status: "error",
          completed_at: DateTime.utc_now(:second),
          error_message: "No saved query assigned"
        })

      {_, nil} ->
        Map.merge(base, %{
          status: "error",
          completed_at: DateTime.utc_now(:second),
          error_message: "No data source assigned to saved query"
        })

      {saved_query, data_source} ->
        case Executor.execute(data_source, saved_query.sql, row_limit: @max_stored_rows) do
          {:ok, result} ->
            Map.merge(base, %{
              status: "success",
              completed_at: DateTime.utc_now(:second),
              duration_ms: result.duration_ms,
              row_count: result.row_count,
              result_columns: result.columns,
              result_rows: %{"rows" => Enum.take(result.rows, @max_stored_rows)}
            })

          {:error, :timeout, message} ->
            Map.merge(base, %{
              status: "timeout",
              completed_at: DateTime.utc_now(:second),
              error_message: message
            })

          {:error, _type, message} ->
            Map.merge(base, %{
              status: "error",
              completed_at: DateTime.utc_now(:second),
              error_message: message
            })
        end
    end
  end
end
