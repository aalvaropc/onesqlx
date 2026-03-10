defmodule Onesqlx.Querying.Executor do
  @moduledoc """
  Executes read-only SQL queries against external PostgreSQL data sources.

  Enforces safety via `SqlGuard` validation, `SET default_transaction_read_only = on`,
  a configurable statement timeout, and a row limit on returned results.
  """

  alias Onesqlx.DataSources
  alias Onesqlx.DataSources.DataSource
  alias Onesqlx.Querying.SqlGuard

  @default_row_limit 1_000
  @connect_timeout 15_000
  @statement_timeout "30000"

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
  """
  @spec execute(DataSource.t(), String.t(), keyword()) ::
          {:ok, result()} | {:error, atom(), String.t()}
  def execute(%DataSource{} = data_source, sql, opts \\ []) do
    row_limit = Keyword.get(opts, :row_limit, @default_row_limit)

    case SqlGuard.validate(sql) do
      {:error, message} ->
        {:error, :blocked, message}

      :ok ->
        with_connection(data_source, fn conn ->
          run_query(conn, sql, row_limit)
        end)
    end
  end

  defp run_query(conn, sql, row_limit) do
    start = System.monotonic_time(:millisecond)

    case Postgrex.query(conn, sql, [], timeout: 35_000) do
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

  defp with_connection(data_source, fun) do
    password = DataSources.decrypt_password(data_source)

    opts = [
      hostname: data_source.host,
      port: data_source.port,
      database: data_source.database_name,
      username: data_source.username,
      password: password,
      ssl: data_source.ssl_enabled,
      pool_size: 1,
      connect_timeout: @connect_timeout,
      after_connect: fn conn ->
        Postgrex.query!(conn, "SET default_transaction_read_only = on", [])
        Postgrex.query!(conn, "SET statement_timeout = '#{@statement_timeout}'", [])
      end
    ]

    old_trap = Process.flag(:trap_exit, true)

    try do
      case Postgrex.start_link(opts) do
        {:ok, conn} ->
          try do
            fun.(conn)
          after
            GenServer.stop(conn)
          end

        {:error, %Postgrex.Error{} = error} ->
          {:error, :connection, Exception.message(error)}

        {:error, %DBConnection.ConnectionError{} = error} ->
          {:error, :connection, Exception.message(error)}

        {:error, error} ->
          {:error, :connection, inspect(error)}
      end
    catch
      :exit, reason ->
        {:error, :connection, "Connection failed: #{inspect(reason)}"}
    after
      Process.flag(:trap_exit, old_trap)

      receive do
        {:EXIT, _pid, _reason} -> :ok
      after
        0 -> :ok
      end
    end
  end
end
