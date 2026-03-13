defmodule Onesqlx.DataSources.Connection.Postgrex do
  @moduledoc """
  Real Postgrex implementation of the `Connection` behaviour.

  Manages ephemeral connections to external PostgreSQL databases with
  proper cleanup and EXIT signal handling.
  """

  @behaviour Onesqlx.DataSources.Connection

  alias Onesqlx.DataSources
  alias Onesqlx.DataSources.DataSource

  @connect_timeout 15_000

  @impl true
  def with_connection(%DataSource{} = data_source, fun) do
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
      end
    ]

    do_with_connection(opts, fun)
  end

  @impl true
  def test_connection(%DataSource{} = data_source) do
    password = DataSources.decrypt_password(data_source)

    do_test(
      hostname: data_source.host,
      port: data_source.port,
      database: data_source.database_name,
      username: data_source.username,
      password: password,
      ssl: data_source.ssl_enabled
    )
  end

  @impl true
  def test_connection_from_attrs(attrs) when is_map(attrs) do
    attrs = for {k, v} <- attrs, into: %{}, do: {to_string(k), v}

    do_test(
      hostname: attrs["host"],
      port: parse_port(attrs["port"]),
      database: attrs["database_name"],
      username: attrs["username"],
      password: attrs["password"],
      ssl: attrs["ssl_enabled"] in [true, "true"]
    )
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp do_with_connection(opts, fun) do
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

  @connect_timeout_test 10_000

  defp do_test(fields) do
    start = System.monotonic_time(:millisecond)

    opts = [
      hostname: fields[:hostname],
      port: fields[:port],
      database: fields[:database],
      username: fields[:username],
      password: fields[:password],
      ssl: fields[:ssl],
      connect_timeout: @connect_timeout_test,
      types: Postgrex.DefaultTypes
    ]

    case Postgrex.Protocol.connect(opts) do
      {:ok, state} ->
        Postgrex.Protocol.disconnect(%RuntimeError{message: "test complete"}, state)
        latency = System.monotonic_time(:millisecond) - start
        {:ok, %{latency_ms: latency}}

      {:error, %Postgrex.Error{} = error} ->
        {:error, translate_error(error)}

      {:error, %DBConnection.ConnectionError{} = error} ->
        {:error, translate_connection_error(error)}
    end
  end

  defp translate_error(%Postgrex.Error{postgres: %{code: :invalid_catalog_name}}) do
    "Database does not exist"
  end

  defp translate_error(%Postgrex.Error{postgres: %{code: :invalid_password}}) do
    "Invalid username or password"
  end

  defp translate_error(%Postgrex.Error{postgres: %{code: :invalid_authorization_specification}}) do
    "Invalid username or password"
  end

  defp translate_error(%Postgrex.Error{} = error) do
    Exception.message(error)
  end

  defp translate_connection_error(%DBConnection.ConnectionError{message: message}) do
    cond do
      message =~ "nxdomain" ->
        "Host not found. Check the hostname."

      message =~ "connection refused" or message =~ "econnrefused" ->
        "Could not reach host. Verify the hostname and port."

      message =~ "timeout" or message =~ "timed out" ->
        "Connection timed out. The host may be unreachable."

      true ->
        "Connection failed: #{message}"
    end
  end

  defp parse_port(port) when is_integer(port), do: port
  defp parse_port(port) when is_binary(port), do: String.to_integer(port)
  defp parse_port(_), do: 5432
end
