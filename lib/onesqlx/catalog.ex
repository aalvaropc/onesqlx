defmodule Onesqlx.Catalog do
  @moduledoc """
  The Catalog context.

  Manages synchronized metadata from external databases, including schemas,
  tables, and columns. Keeps an up-to-date representation of the external
  database structure for exploration and query building.
  """

  import Ecto.Query

  alias Onesqlx.Accounts.Scope
  alias Onesqlx.Catalog.CatalogColumn
  alias Onesqlx.Catalog.CatalogSchema
  alias Onesqlx.Catalog.CatalogTable
  alias Onesqlx.DataSources.DataSource
  alias Onesqlx.Repo

  @doc """
  Lists all catalog schemas for a data source, scoped to the workspace.
  """
  def list_schemas(%Scope{} = scope, data_source_id) do
    CatalogSchema
    |> join(:inner, [cs], ds in DataSource,
      on: cs.data_source_id == ds.id and ds.workspace_id == ^scope.workspace.id
    )
    |> where([cs], cs.data_source_id == ^data_source_id)
    |> order_by([cs], cs.name)
    |> Repo.all()
  end

  @doc """
  Gets a single catalog schema by ID, scoped to the workspace.
  """
  def get_schema!(%Scope{} = scope, schema_id) do
    CatalogSchema
    |> join(:inner, [cs], ds in DataSource,
      on: cs.data_source_id == ds.id and ds.workspace_id == ^scope.workspace.id
    )
    |> where([cs], cs.id == ^schema_id)
    |> Repo.one!()
  end

  @doc """
  Lists all tables for a catalog schema, scoped to the workspace.
  """
  def list_tables(%Scope{} = scope, catalog_schema_id) do
    CatalogTable
    |> join(:inner, [ct], ds in DataSource,
      on: ct.data_source_id == ds.id and ds.workspace_id == ^scope.workspace.id
    )
    |> where([ct], ct.catalog_schema_id == ^catalog_schema_id)
    |> order_by([ct], ct.name)
    |> Repo.all()
  end

  @doc """
  Lists all columns for a catalog table, scoped to the workspace.
  """
  def list_columns(%Scope{} = scope, catalog_table_id) do
    CatalogColumn
    |> join(:inner, [cc], ds in DataSource,
      on: cc.data_source_id == ds.id and ds.workspace_id == ^scope.workspace.id
    )
    |> where([cc], cc.catalog_table_id == ^catalog_table_id)
    |> order_by([cc], cc.ordinal_position)
    |> Repo.all()
  end

  @doc """
  Returns whether a data source has been synced (has any catalog schemas).
  """
  def synced?(%Scope{} = scope, data_source_id) do
    CatalogSchema
    |> join(:inner, [cs], ds in DataSource,
      on: cs.data_source_id == ds.id and ds.workspace_id == ^scope.workspace.id
    )
    |> where([cs], cs.data_source_id == ^data_source_id)
    |> Repo.exists?()
  end

  @doc """
  Returns catalog statistics for a data source.
  """
  def catalog_stats(%Scope{} = scope, data_source_id) do
    schemas_count =
      CatalogSchema
      |> join(:inner, [cs], ds in DataSource,
        on: cs.data_source_id == ds.id and ds.workspace_id == ^scope.workspace.id
      )
      |> where([cs], cs.data_source_id == ^data_source_id)
      |> Repo.aggregate(:count)

    tables_count =
      CatalogTable
      |> join(:inner, [ct], ds in DataSource,
        on: ct.data_source_id == ds.id and ds.workspace_id == ^scope.workspace.id
      )
      |> where([ct], ct.data_source_id == ^data_source_id)
      |> Repo.aggregate(:count)

    columns_count =
      CatalogColumn
      |> join(:inner, [cc], ds in DataSource,
        on: cc.data_source_id == ds.id and ds.workspace_id == ^scope.workspace.id
      )
      |> where([cc], cc.data_source_id == ^data_source_id)
      |> Repo.aggregate(:count)

    %{schemas: schemas_count, tables: tables_count, columns: columns_count}
  end

  @doc """
  Syncs catalog metadata for a data source. Deletes all existing metadata
  and inserts fresh data in a single transaction.
  """
  def sync_catalog(%DataSource{} = data_source, introspection_data) do
    Repo.transaction(fn ->
      delete_catalog(data_source)

      schema_map =
        Enum.reduce(introspection_data.schemas, %{}, fn schema_name, acc ->
          {:ok, catalog_schema} =
            %CatalogSchema{}
            |> CatalogSchema.changeset(%{
              name: schema_name,
              data_source_id: data_source.id
            })
            |> Repo.insert()

          Map.put(acc, schema_name, catalog_schema)
        end)

      table_map =
        Enum.reduce(introspection_data.tables, %{}, fn table_data, acc ->
          catalog_schema = Map.fetch!(schema_map, table_data.schema)

          {:ok, catalog_table} =
            %CatalogTable{}
            |> CatalogTable.changeset(%{
              name: table_data.name,
              table_type: table_data.table_type,
              estimated_row_count: table_data.estimated_row_count,
              catalog_schema_id: catalog_schema.id,
              data_source_id: data_source.id
            })
            |> Repo.insert()

          Map.put(acc, {table_data.schema, table_data.name}, catalog_table)
        end)

      Enum.each(introspection_data.columns, fn col_data ->
        catalog_table = Map.fetch!(table_map, {col_data.schema, col_data.table})

        %CatalogColumn{}
        |> CatalogColumn.changeset(%{
          name: col_data.name,
          data_type: col_data.data_type,
          ordinal_position: col_data.ordinal_position,
          is_nullable: col_data.is_nullable,
          column_default: col_data.column_default,
          is_primary_key: col_data.is_primary_key,
          character_maximum_length: col_data.character_maximum_length,
          catalog_table_id: catalog_table.id,
          data_source_id: data_source.id
        })
        |> Repo.insert!()
      end)
    end)
  end

  @doc """
  Deletes all catalog metadata for a data source.
  """
  def delete_catalog(%DataSource{} = data_source) do
    CatalogSchema
    |> where(data_source_id: ^data_source.id)
    |> Repo.delete_all()
  end
end
