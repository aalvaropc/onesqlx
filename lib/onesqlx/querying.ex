defmodule Onesqlx.Querying do
  @moduledoc """
  The Querying context.

  Handles read-only SQL execution against external data sources. Provides
  controlled query execution with timeouts, row limits, and result formatting.
  """

  import Ecto.Query

  alias Onesqlx.Accounts.Scope
  alias Onesqlx.Audit
  alias Onesqlx.DataSources.DataSource
  alias Onesqlx.Querying.Executor
  alias Onesqlx.Querying.QueryRun
  alias Onesqlx.Repo

  @doc """
  Executes a SQL query and records the run for audit.

  Returns the result from `Executor.execute/2`.
  """
  def execute_query(%Scope{} = scope, %DataSource{} = data_source, sql, params \\ %{}) do
    started_at = DateTime.utc_now(:second)
    start_mono = System.monotonic_time(:millisecond)
    result = Executor.execute(data_source, sql, params: params)
    duration_ms = System.monotonic_time(:millisecond) - start_mono

    run_attrs = build_run_attrs(scope, data_source, sql, result, duration_ms, started_at)
    {:ok, _run} = record_query_run(scope, run_attrs)

    emit_audit(scope, data_source, sql, run_attrs)

    result
  end

  @doc """
  Records a query run for audit purposes.
  """
  def record_query_run(%Scope{} = scope, attrs) do
    %QueryRun{workspace_id: scope.workspace.id}
    |> QueryRun.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists recent query runs for the current user and data source.

  Results are ordered by `executed_at` descending. Accepts an optional `:limit`
  option (default: 20).
  """
  def list_recent_runs(%Scope{} = scope, data_source_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    QueryRun
    |> where(workspace_id: ^scope.workspace.id, user_id: ^scope.user.id)
    |> where(data_source_id: ^data_source_id)
    |> order_by(desc: :executed_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Gets a single query run by ID, scoped to the workspace.

  Raises `Ecto.NoResultsError` if not found.
  """
  def get_query_run!(%Scope{} = scope, id) do
    QueryRun
    |> where(workspace_id: ^scope.workspace.id, id: ^id)
    |> Repo.one!()
  end

  defp emit_audit(scope, data_source, sql, run_attrs) do
    Task.start(fn ->
      Audit.record_event(scope, "query.executed", %{
        resource_type: "data_source",
        resource_id: data_source.id,
        metadata: %{sql_preview: String.slice(sql, 0, 200), status: run_attrs.status}
      })
    end)
  end

  defp build_run_attrs(scope, data_source, sql, result, duration_ms, started_at) do
    base = %{
      sql: sql,
      executed_at: started_at,
      duration_ms: duration_ms,
      user_id: scope.user.id,
      data_source_id: data_source.id
    }

    case result do
      {:ok, %{row_count: row_count}} ->
        Map.merge(base, %{status: "success", row_count: row_count})

      {:error, :blocked, message} ->
        Map.merge(base, %{status: "blocked", error_message: message})

      {:error, :timeout, message} ->
        Map.merge(base, %{status: "timeout", error_message: message})

      {:error, _type, message} ->
        Map.merge(base, %{status: "error", error_message: message})
    end
  end
end
