defmodule Onesqlx.DataSources do
  @moduledoc """
  The DataSources context.

  Manages connections to external PostgreSQL databases. Handles connection
  configuration, credentials, and connectivity validation.
  """

  import Ecto.Query

  alias Onesqlx.Accounts.Scope
  alias Onesqlx.DataSources.ConnectionTester
  alias Onesqlx.DataSources.DataSource
  alias Onesqlx.DataSources.Encryption
  alias Onesqlx.Repo

  @doc """
  Lists all data sources for the workspace in the given scope.
  """
  def list_data_sources(%Scope{} = scope) do
    DataSource
    |> where(workspace_id: ^scope.workspace.id)
    |> order_by(:name)
    |> Repo.all()
  end

  @doc """
  Gets a single data source by ID, scoped to the workspace.

  Raises `Ecto.NoResultsError` if not found.
  """
  def get_data_source!(%Scope{} = scope, id) do
    DataSource
    |> where(workspace_id: ^scope.workspace.id, id: ^id)
    |> Repo.one!()
  end

  @doc """
  Creates a data source for the workspace in the given scope.
  """
  def create_data_source(%Scope{} = scope, attrs) do
    %DataSource{workspace_id: scope.workspace.id}
    |> DataSource.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates the status of a data source.
  """
  def update_data_source_status(%DataSource{} = data_source, status) do
    data_source
    |> DataSource.status_changeset(%{status: status})
    |> Repo.update()
  end

  @doc """
  Returns a changeset for tracking data source changes.
  """
  def change_data_source(%DataSource{} = data_source, attrs \\ %{}) do
    DataSource.changeset(data_source, attrs)
  end

  @doc """
  Decrypts the password of a data source.
  """
  def decrypt_password(%DataSource{} = data_source) do
    Encryption.decrypt(data_source.encrypted_password)
  end

  @doc """
  Tests connection to an existing data source.
  """
  def test_connection(%DataSource{} = data_source) do
    ConnectionTester.test_connection(data_source)
  end

  @doc """
  Tests connection from raw attributes (before persisting).
  """
  def test_connection_from_attrs(attrs) do
    ConnectionTester.test_connection_from_attrs(attrs)
  end
end
