defmodule Onesqlx.CatalogTest do
  use Onesqlx.DataCase, async: true

  alias Onesqlx.Catalog

  import Onesqlx.AccountsFixtures
  import Onesqlx.CatalogFixtures
  import Onesqlx.DataSourcesFixtures

  setup do
    scope = user_scope_fixture()
    data_source = data_source_fixture(scope)
    %{scope: scope, data_source: data_source}
  end

  describe "list_schemas/2" do
    test "returns schemas for the data source scoped to workspace", %{
      scope: scope,
      data_source: data_source
    } do
      schema1 = catalog_schema_fixture(data_source, %{name: "alpha"})
      schema2 = catalog_schema_fixture(data_source, %{name: "beta"})

      result = Catalog.list_schemas(scope, data_source.id)
      assert length(result) == 2
      assert Enum.at(result, 0).id == schema1.id
      assert Enum.at(result, 1).id == schema2.id
    end

    test "does not return schemas from another workspace", %{data_source: data_source} do
      catalog_schema_fixture(data_source)

      other_scope = user_scope_fixture()
      assert Catalog.list_schemas(other_scope, data_source.id) == []
    end
  end

  describe "get_schema!/2" do
    test "returns the schema scoped to workspace", %{scope: scope, data_source: data_source} do
      schema = catalog_schema_fixture(data_source)
      assert Catalog.get_schema!(scope, schema.id).id == schema.id
    end

    test "raises for schema in another workspace", %{data_source: data_source} do
      schema = catalog_schema_fixture(data_source)
      other_scope = user_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Catalog.get_schema!(other_scope, schema.id)
      end
    end
  end

  describe "list_tables/2" do
    test "returns tables ordered by name", %{scope: scope, data_source: data_source} do
      schema = catalog_schema_fixture(data_source)
      table_b = catalog_table_fixture(data_source, schema, %{name: "beta_table"})
      table_a = catalog_table_fixture(data_source, schema, %{name: "alpha_table"})

      result = Catalog.list_tables(scope, schema.id)
      assert length(result) == 2
      assert Enum.at(result, 0).id == table_a.id
      assert Enum.at(result, 1).id == table_b.id
    end
  end

  describe "list_columns/2" do
    test "returns columns ordered by ordinal_position", %{
      scope: scope,
      data_source: data_source
    } do
      schema = catalog_schema_fixture(data_source)
      table = catalog_table_fixture(data_source, schema)
      col2 = catalog_column_fixture(data_source, table, %{name: "b", ordinal_position: 2})
      col1 = catalog_column_fixture(data_source, table, %{name: "a", ordinal_position: 1})

      result = Catalog.list_columns(scope, table.id)
      assert length(result) == 2
      assert Enum.at(result, 0).id == col1.id
      assert Enum.at(result, 1).id == col2.id
    end
  end

  describe "synced?/2" do
    test "returns false when no schemas exist", %{scope: scope, data_source: data_source} do
      refute Catalog.synced?(scope, data_source.id)
    end

    test "returns true when schemas exist", %{scope: scope, data_source: data_source} do
      catalog_schema_fixture(data_source)
      assert Catalog.synced?(scope, data_source.id)
    end
  end

  describe "catalog_stats/2" do
    test "returns counts", %{scope: scope, data_source: data_source} do
      schema = catalog_schema_fixture(data_source)
      table = catalog_table_fixture(data_source, schema)
      catalog_column_fixture(data_source, table)
      catalog_column_fixture(data_source, table, %{name: "col2", ordinal_position: 2})

      stats = Catalog.catalog_stats(scope, data_source.id)
      assert stats == %{schemas: 1, tables: 1, columns: 2}
    end
  end

  describe "sync_catalog/2" do
    test "inserts schemas, tables, and columns", %{data_source: data_source, scope: scope} do
      introspection_data = %{
        schemas: ["public"],
        tables: [
          %{
            schema: "public",
            name: "users",
            table_type: "BASE TABLE",
            estimated_row_count: 42
          }
        ],
        columns: [
          %{
            schema: "public",
            table: "users",
            name: "id",
            data_type: "uuid",
            ordinal_position: 1,
            is_nullable: false,
            column_default: "gen_random_uuid()",
            is_primary_key: true,
            character_maximum_length: nil
          },
          %{
            schema: "public",
            table: "users",
            name: "email",
            data_type: "text",
            ordinal_position: 2,
            is_nullable: false,
            column_default: nil,
            is_primary_key: false,
            character_maximum_length: nil
          }
        ]
      }

      assert {:ok, _} = Catalog.sync_catalog(data_source, introspection_data)

      schemas = Catalog.list_schemas(scope, data_source.id)
      assert length(schemas) == 1
      assert Enum.at(schemas, 0).name == "public"

      tables = Catalog.list_tables(scope, Enum.at(schemas, 0).id)
      assert length(tables) == 1
      assert Enum.at(tables, 0).name == "users"
      assert Enum.at(tables, 0).estimated_row_count == 42

      columns = Catalog.list_columns(scope, Enum.at(tables, 0).id)
      assert length(columns) == 2
      assert Enum.at(columns, 0).name == "id"
      assert Enum.at(columns, 0).is_primary_key == true
      assert Enum.at(columns, 1).name == "email"
    end

    test "re-sync replaces existing data", %{data_source: data_source, scope: scope} do
      initial = %{
        schemas: ["public"],
        tables: [
          %{schema: "public", name: "old_table", table_type: "BASE TABLE", estimated_row_count: 0}
        ],
        columns: [
          %{
            schema: "public",
            table: "old_table",
            name: "id",
            data_type: "integer",
            ordinal_position: 1,
            is_nullable: false,
            column_default: nil,
            is_primary_key: true,
            character_maximum_length: nil
          }
        ]
      }

      updated = %{
        schemas: ["public", "analytics"],
        tables: [
          %{
            schema: "public",
            name: "new_table",
            table_type: "BASE TABLE",
            estimated_row_count: 10
          },
          %{
            schema: "analytics",
            name: "events",
            table_type: "BASE TABLE",
            estimated_row_count: 1000
          }
        ],
        columns: [
          %{
            schema: "public",
            table: "new_table",
            name: "id",
            data_type: "uuid",
            ordinal_position: 1,
            is_nullable: false,
            column_default: nil,
            is_primary_key: true,
            character_maximum_length: nil
          },
          %{
            schema: "analytics",
            table: "events",
            name: "id",
            data_type: "bigint",
            ordinal_position: 1,
            is_nullable: false,
            column_default: nil,
            is_primary_key: true,
            character_maximum_length: nil
          }
        ]
      }

      {:ok, _} = Catalog.sync_catalog(data_source, initial)
      {:ok, _} = Catalog.sync_catalog(data_source, updated)

      schemas = Catalog.list_schemas(scope, data_source.id)
      assert length(schemas) == 2
      assert Enum.map(schemas, & &1.name) == ["analytics", "public"]
    end
  end

  describe "delete_catalog/1" do
    test "removes all catalog data for a data source", %{
      scope: scope,
      data_source: data_source
    } do
      schema = catalog_schema_fixture(data_source)
      table = catalog_table_fixture(data_source, schema)
      catalog_column_fixture(data_source, table)

      Catalog.delete_catalog(data_source)

      assert Catalog.list_schemas(scope, data_source.id) == []
      assert Catalog.catalog_stats(scope, data_source.id) == %{schemas: 0, tables: 0, columns: 0}
    end
  end
end
