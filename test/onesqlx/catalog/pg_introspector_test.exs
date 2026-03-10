defmodule Onesqlx.Catalog.PgIntrospectorTest do
  use Onesqlx.DataCase, async: true

  alias Onesqlx.Catalog.PgIntrospector

  import Onesqlx.AccountsFixtures
  import Onesqlx.DataSourcesFixtures

  @moduletag timeout: 30_000

  setup do
    scope = user_scope_fixture()
    # Point data source at the test database itself
    config = test_db_config()

    data_source =
      data_source_fixture(scope, %{
        host: config[:hostname],
        port: config[:port] || 5432,
        database_name: config[:database],
        username: config[:username],
        password: config[:password]
      })

    %{data_source: data_source}
  end

  describe "introspect/1" do
    test "returns schemas including public but not pg_catalog", %{data_source: data_source} do
      assert {:ok, result} = PgIntrospector.introspect(data_source)
      assert "public" in result.schemas
      refute "pg_catalog" in result.schemas
      refute "information_schema" in result.schemas
    end

    test "returns tables from the test database", %{data_source: data_source} do
      assert {:ok, result} = PgIntrospector.introspect(data_source)

      table_names = Enum.map(result.tables, & &1.name)
      assert "users" in table_names
      assert "data_sources" in table_names

      users_table = Enum.find(result.tables, &(&1.name == "users"))
      assert users_table.schema == "public"
      assert users_table.table_type == "BASE TABLE"
    end

    test "returns columns with types and PK info", %{data_source: data_source} do
      assert {:ok, result} = PgIntrospector.introspect(data_source)

      users_columns =
        Enum.filter(result.columns, &(&1.schema == "public" and &1.table == "users"))

      assert users_columns != []

      id_col = Enum.find(users_columns, &(&1.name == "id"))
      assert id_col.is_primary_key == true
      assert id_col.data_type == "uuid"

      email_col = Enum.find(users_columns, &(&1.name == "email"))
      assert email_col.is_nullable == false
      assert email_col.is_primary_key == false
    end
  end
end
