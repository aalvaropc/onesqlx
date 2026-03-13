defmodule Onesqlx.DataSources.Connection do
  @moduledoc """
  Behaviour for connecting to external data sources.

  Abstracts the connection lifecycle so that production code uses real Postgrex
  connections while tests can substitute a mock.
  """

  alias Onesqlx.DataSources.DataSource

  @type connection :: pid()

  @doc """
  Opens a connection to the data source, executes the given function,
  and ensures the connection is cleaned up afterward.

  The function receives a connection pid and should return the operation result.
  """
  @callback with_connection(DataSource.t(), (connection() -> term())) ::
              {:ok, term()} | {:error, term()}

  @doc """
  Tests connectivity to a data source and returns latency information.
  """
  @callback test_connection(DataSource.t()) ::
              {:ok, %{latency_ms: integer()}} | {:error, String.t()}

  @doc """
  Tests connectivity from raw attributes (before persisting a data source).
  """
  @callback test_connection_from_attrs(map()) ::
              {:ok, %{latency_ms: integer()}} | {:error, String.t()}

  @doc """
  Returns the configured connection module.
  """
  def impl do
    Application.get_env(:onesqlx, :connection_module, Onesqlx.DataSources.Connection.Postgrex)
  end
end
