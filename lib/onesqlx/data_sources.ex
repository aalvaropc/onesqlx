defmodule Onesqlx.DataSources do
  @moduledoc """
  The DataSources context.

  Manages connections to external PostgreSQL databases. Handles connection
  configuration, credentials, and connectivity validation.
  """

  import Ecto.Query

  alias Onesqlx.Accounts.Scope
  alias Onesqlx.Audit
  alias Onesqlx.DataSources.ConnectionTester
  alias Onesqlx.DataSources.DataSource
  alias Onesqlx.DataSources.Encryption
  alias Onesqlx.Repo

  @spec list_data_sources(Scope.t(), keyword()) :: [DataSource.t()]
  @doc """
  Lists all data sources for the workspace in the given scope.
  """
  def list_data_sources(%Scope{} = scope, opts \\ []) do
    DataSource
    |> where(workspace_id: ^scope.workspace.id)
    |> order_by(:name)
    |> maybe_apply_limit(opts[:limit])
    |> maybe_apply_offset(opts[:offset])
    |> Repo.all()
  end

  @spec count_data_sources(Scope.t()) :: non_neg_integer()
  @doc """
  Counts data sources for the workspace.
  """
  def count_data_sources(%Scope{} = scope) do
    DataSource
    |> where(workspace_id: ^scope.workspace.id)
    |> Repo.aggregate(:count)
  end

  @spec get_data_source!(Scope.t(), String.t()) :: DataSource.t()
  @doc """
  Gets a single data source by ID, scoped to the workspace.

  Raises `Ecto.NoResultsError` if not found.
  """
  def get_data_source!(%Scope{} = scope, id) do
    DataSource
    |> where(workspace_id: ^scope.workspace.id, id: ^id)
    |> Repo.one!()
  end

  @spec create_data_source(Scope.t(), map()) ::
          {:ok, DataSource.t()} | {:error, Ecto.Changeset.t()}
  @doc """
  Creates a data source for the workspace in the given scope.
  """
  def create_data_source(%Scope{} = scope, attrs) do
    result =
      %DataSource{workspace_id: scope.workspace.id}
      |> DataSource.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, ds} ->
        Audit.safe_record_event(scope, "data_source.created", %{
          resource_type: "data_source",
          resource_id: ds.id
        })

      _ ->
        :ok
    end

    result
  end

  @spec update_data_source_status(DataSource.t(), String.t()) ::
          {:ok, DataSource.t()} | {:error, Ecto.Changeset.t()}
  @doc """
  Updates the status of a data source.
  """
  def update_data_source_status(%DataSource{} = data_source, status) do
    data_source
    |> DataSource.status_changeset(%{status: status})
    |> Repo.update()
  end

  @spec change_data_source(DataSource.t(), map()) :: Ecto.Changeset.t()
  @doc """
  Returns a changeset for tracking data source changes.
  """
  def change_data_source(%DataSource{} = data_source, attrs \\ %{}) do
    DataSource.changeset(data_source, attrs)
  end

  @spec decrypt_password(DataSource.t()) :: String.t() | nil
  @doc """
  Decrypts the password of a data source.
  """
  def decrypt_password(%DataSource{} = data_source) do
    Encryption.decrypt(data_source.encrypted_password)
  end

  @spec test_connection(DataSource.t()) :: {:ok, map()} | {:error, String.t()}
  @doc """
  Tests connection to an existing data source.
  """
  def test_connection(%DataSource{} = data_source) do
    ConnectionTester.test_connection(data_source)
  end

  @spec test_connection_from_attrs(map()) :: {:ok, map()} | {:error, String.t()}
  @doc """
  Tests connection from raw attributes (before persisting).
  """
  def test_connection_from_attrs(attrs) do
    ConnectionTester.test_connection_from_attrs(attrs)
  end

  defp maybe_apply_limit(query, nil), do: query
  defp maybe_apply_limit(query, limit), do: limit(query, ^limit)

  defp maybe_apply_offset(query, nil), do: query
  defp maybe_apply_offset(query, offset), do: offset(query, ^offset)
end
