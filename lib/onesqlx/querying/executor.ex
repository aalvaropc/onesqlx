defmodule Onesqlx.Querying.Executor do
  @moduledoc """
  Executes read-only SQL queries against external PostgreSQL data sources.

  Enforces safety via `SqlGuard` validation, `SET default_transaction_read_only = on`,
  a configurable statement timeout, and a row limit on returned results.
  """

  alias Onesqlx.DataSources.Connection
  alias Onesqlx.DataSources.DataSource
  alias Onesqlx.Querying.CancelRegistry
  alias Onesqlx.Querying.Params
  alias Onesqlx.Querying.QueryCache
  alias Onesqlx.Querying.SqlGuard

  @default_row_limit 1_000
  @default_statement_timeout_ms 30_000
  # The client-side timeout exceeds the server statement_timeout so the
  # server cancels first and we surface :query_canceled as {:error, :timeout, _}
  @client_timeout_margin_ms 5_000

  @type result :: %{
          columns: [String.t()],
          rows: [[term()]],
          row_count: integer(),
          duration_ms: integer()
        }

  @doc """
  Executes a SQL query against the given data source.

  Returns `{:ok, result}` on success or `{:error, error_type, message}` on failure.
  The `error_type` is one of `:blocked`, `:timeout`, `:execution`, or `:connection`.

  ## Options

    * `:row_limit` — max rows returned (default 1000)
    * `:params` — map of named parameter values for `:param_name` substitution
    * `:cancel_ref` — unique reference for query cancellation support
    * `:cache_ttl` — cache TTL in milliseconds; when set, results are cached
    * `:skip_cache` — when `true`, bypasses cache read but still writes result
  """
  @spec execute(DataSource.t(), String.t(), keyword()) ::
          {:ok, result()} | {:error, atom(), String.t()}
  def execute(%DataSource{} = data_source, sql, opts \\ []) do
    row_limit =
      opts
      |> Keyword.get(:row_limit, @default_row_limit)
      |> cap_row_limit(data_source.max_row_limit)

    params = Keyword.get(opts, :params, %{})
    cancel_ref = Keyword.get(opts, :cancel_ref)
    cache_ttl = Keyword.get(opts, :cache_ttl)
    skip_cache = Keyword.get(opts, :skip_cache, false)

    {prepared_sql, values} =
      if params != %{} && Params.parameterized?(sql) do
        Params.substitute(sql, params)
      else
        {sql, []}
      end

    case validate_guard(data_source, prepared_sql) do
      {:error, message} ->
        {:error, :blocked, message}

      :ok ->
        maybe_cached_execute(
          data_source,
          prepared_sql,
          values,
          row_limit,
          cancel_ref,
          cache_ttl,
          skip_cache,
          params
        )
    end
  end

  @doc """
  Cancels a running query by sending `pg_cancel_backend` to PostgreSQL.

  Opens a new connection to the same data source and sends the cancel signal.
  Returns `:ok` regardless of whether the query was found or already finished.
  """
  def cancel_query(%DataSource{} = data_source, cancel_ref) do
    case CancelRegistry.lookup(cancel_ref) do
      {:ok, backend_pid} ->
        CancelRegistry.unregister(cancel_ref)

        Connection.impl().with_connection(data_source, fn conn ->
          Postgrex.query(conn, "SELECT pg_cancel_backend($1)", [backend_pid])
        end)

        :ok

      :error ->
        :ok
    end
  end

  @doc """
  Runs EXPLAIN ANALYZE on a SQL query and returns the plan as text.

  Returns `{:ok, plan_text}` or `{:error, error_type, message}`.
  """
  @spec explain(DataSource.t(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, atom(), String.t()}
  def explain(%DataSource{} = data_source, sql, opts \\ []) do
    params = Keyword.get(opts, :params, %{})

    {prepared_sql, values} =
      if params != %{} && Params.parameterized?(sql) do
        Params.substitute(sql, params)
      else
        {sql, []}
      end

    case validate_guard(data_source, prepared_sql) do
      {:error, message} ->
        {:error, :blocked, message}

      :ok ->
        timeout_ms = statement_timeout_ms(data_source)

        Connection.impl().with_connection(data_source, fn conn ->
          set_statement_timeout(conn, timeout_ms)
          run_explain(conn, prepared_sql, values, timeout_ms + @client_timeout_margin_ms)
        end)
    end
  end

  # Data sources explicitly marked writable (read_only: false) skip the
  # lexical write guard; the session-level read-only flag is skipped too
  # (see Connection.Postgrex.with_connection/2).
  defp validate_guard(%DataSource{read_only: false}, _sql), do: :ok
  defp validate_guard(_data_source, sql), do: SqlGuard.validate(sql)

  defp run_explain(conn, sql, values, client_timeout_ms) do
    explain_sql = "EXPLAIN (ANALYZE, COSTS, BUFFERS, FORMAT TEXT) #{sql}"

    case Postgrex.query(conn, explain_sql, values, timeout: client_timeout_ms) do
      {:ok, %Postgrex.Result{rows: rows}} ->
        plan_text = Enum.map_join(rows, "\n", &List.first/1)
        {:ok, plan_text}

      {:error, %Postgrex.Error{postgres: %{code: :query_canceled}} = error} ->
        {:error, :timeout, Exception.message(error)}

      {:error, %Postgrex.Error{} = error} ->
        {:error, :execution, Exception.message(error)}
    end
  end

  defp maybe_cached_execute(data_source, sql, values, row_limit, cancel_ref, nil, _skip, _params) do
    do_execute(data_source, sql, values, row_limit, cancel_ref)
  end

  defp maybe_cached_execute(
         data_source,
         sql,
         values,
         row_limit,
         cancel_ref,
         cache_ttl,
         true,
         params
       ) do
    execute_and_cache(data_source, sql, values, row_limit, cancel_ref, cache_ttl, params)
  end

  defp maybe_cached_execute(
         data_source,
         sql,
         values,
         row_limit,
         cancel_ref,
         cache_ttl,
         false,
         params
       ) do
    case QueryCache.get(data_source.id, sql, params) do
      {:hit, result} ->
        {:ok, result}

      :miss ->
        execute_and_cache(data_source, sql, values, row_limit, cancel_ref, cache_ttl, params)
    end
  end

  defp execute_and_cache(data_source, sql, values, row_limit, cancel_ref, cache_ttl, params) do
    result = do_execute(data_source, sql, values, row_limit, cancel_ref)
    maybe_store_in_cache(result, data_source.id, sql, params, cache_ttl)
    result
  end

  defp maybe_store_in_cache({:ok, data}, ds_id, sql, params, ttl) do
    QueryCache.put(ds_id, sql, params, data, ttl)
  end

  defp maybe_store_in_cache(_error, _ds_id, _sql, _params, _ttl), do: :ok

  defp do_execute(data_source, sql, values, row_limit, cancel_ref) do
    timeout_ms = statement_timeout_ms(data_source)

    Connection.impl().with_connection(data_source, fn conn ->
      set_statement_timeout(conn, timeout_ms)
      register_cancel(conn, cancel_ref)

      try do
        run_query(conn, sql, values, row_limit, timeout_ms + @client_timeout_margin_ms)
      after
        unregister_cancel(cancel_ref)
      end
    end)
  end

  defp statement_timeout_ms(%DataSource{statement_timeout_ms: ms}) when is_integer(ms), do: ms
  defp statement_timeout_ms(_data_source), do: @default_statement_timeout_ms

  # The value is an integer from a validated schema field, never raw input
  defp set_statement_timeout(conn, timeout_ms) do
    Postgrex.query!(conn, "SET statement_timeout = '#{timeout_ms}'", [])
  end

  defp cap_row_limit(requested, nil), do: requested
  defp cap_row_limit(requested, max) when is_integer(max), do: min(requested, max)

  defp register_cancel(_conn, nil), do: :ok

  defp register_cancel(conn, cancel_ref) do
    case Postgrex.query(conn, "SELECT pg_backend_pid()", []) do
      {:ok, %Postgrex.Result{rows: [[backend_pid]]}} ->
        CancelRegistry.register(cancel_ref, backend_pid)

      _ ->
        :ok
    end
  end

  defp unregister_cancel(nil), do: :ok
  defp unregister_cancel(cancel_ref), do: CancelRegistry.unregister(cancel_ref)

  defp run_query(conn, sql, values, row_limit, client_timeout_ms) do
    start = System.monotonic_time(:millisecond)

    case Postgrex.query(conn, sql, values, timeout: client_timeout_ms) do
      {:ok, %Postgrex.Result{columns: columns, rows: rows, num_rows: num_rows}} ->
        duration_ms = System.monotonic_time(:millisecond) - start
        truncated_rows = Enum.take(rows, row_limit)

        {:ok,
         %{
           columns: columns,
           rows: truncated_rows,
           row_count: num_rows,
           duration_ms: duration_ms
         }}

      {:error, %Postgrex.Error{postgres: %{code: :query_canceled}} = error} ->
        {:error, :timeout, Exception.message(error)}

      {:error, %Postgrex.Error{} = error} ->
        {:error, :execution, Exception.message(error)}
    end
  end
end
