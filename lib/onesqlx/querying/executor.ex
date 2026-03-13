defmodule Onesqlx.Querying.Executor do
  @moduledoc """
  Executes read-only SQL queries against external PostgreSQL data sources.

  Enforces safety via `SqlGuard` validation, `SET default_transaction_read_only = on`,
  a configurable statement timeout, and a row limit on returned results.
  """

  alias Onesqlx.DataSources.Connection
  alias Onesqlx.DataSources.DataSource
  alias Onesqlx.Querying.SqlGuard

  @default_row_limit 1_000
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
        Connection.impl().with_connection(data_source, fn conn ->
          Postgrex.query!(conn, "SET statement_timeout = '#{@statement_timeout}'", [])
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
end
