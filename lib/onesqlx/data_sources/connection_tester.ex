defmodule Onesqlx.DataSources.ConnectionTester do
  @moduledoc """
  Tests connectivity to external PostgreSQL databases.

  Delegates to the configured `Connection` implementation, allowing
  tests to substitute a mock.
  """

  alias Onesqlx.DataSources.Connection
  alias Onesqlx.DataSources.DataSource

  @doc """
  Tests connection to an existing data source by decrypting its stored password.
  """
  def test_connection(%DataSource{} = data_source) do
    Connection.impl().test_connection(data_source)
  end

  @doc """
  Tests connection from raw attributes (e.g. form params before persisting).
  """
  def test_connection_from_attrs(attrs) when is_map(attrs) do
    Connection.impl().test_connection_from_attrs(attrs)
  end
end
