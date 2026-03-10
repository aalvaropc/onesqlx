defmodule Onesqlx.CatalogFixtures do
  @moduledoc """
  Test helpers for creating catalog entities.
  """

  alias Onesqlx.Catalog.CatalogColumn
  alias Onesqlx.Catalog.CatalogSchema
  alias Onesqlx.Catalog.CatalogTable
  alias Onesqlx.Repo

  def catalog_schema_fixture(data_source, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "schema_#{System.unique_integer([:positive])}",
        data_source_id: data_source.id
      })

    %CatalogSchema{}
    |> CatalogSchema.changeset(attrs)
    |> Repo.insert!()
  end

  def catalog_table_fixture(data_source, catalog_schema, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "table_#{System.unique_integer([:positive])}",
        table_type: "BASE TABLE",
        estimated_row_count: 100,
        catalog_schema_id: catalog_schema.id,
        data_source_id: data_source.id
      })

    %CatalogTable{}
    |> CatalogTable.changeset(attrs)
    |> Repo.insert!()
  end

  def catalog_column_fixture(data_source, catalog_table, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "column_#{System.unique_integer([:positive])}",
        data_type: "text",
        ordinal_position: 1,
        is_nullable: true,
        is_primary_key: false,
        catalog_table_id: catalog_table.id,
        data_source_id: data_source.id
      })

    %CatalogColumn{}
    |> CatalogColumn.changeset(attrs)
    |> Repo.insert!()
  end
end
