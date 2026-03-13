defmodule Onesqlx.Querying.ExecutorTest do
  use Onesqlx.DataCase, async: false

  @moduletag :integration

  alias Onesqlx.Querying.Executor

  import Onesqlx.AccountsFixtures
  import Onesqlx.DataSourcesFixtures

  setup do
    Application.put_env(:onesqlx, :connection_module, Onesqlx.DataSources.Connection.Postgrex)

    on_exit(fn ->
      Application.put_env(:onesqlx, :connection_module, Onesqlx.DataSources.MockConnection)
    end)

    scope = user_scope_fixture()

    # Create a data source pointing at the test database itself
    config = Application.get_env(:onesqlx, Onesqlx.Repo)

    data_source =
      data_source_fixture(scope, %{
        name: "executor-test-db",
        host: config[:hostname],
        port: config[:port] || 5432,
        database_name: config[:database],
        username: config[:username],
        password: config[:password]
      })

    %{data_source: data_source}
  end

  describe "execute/2" do
    test "executes SELECT and returns columns and rows", %{data_source: ds} do
      assert {:ok, result} = Executor.execute(ds, "SELECT 1 AS num, 'hello' AS greeting")
      assert result.columns == ["num", "greeting"]
      assert result.rows == [[1, "hello"]]
      assert result.row_count == 1
      assert is_integer(result.duration_ms)
    end

    test "executes query returning multiple rows", %{data_source: ds} do
      sql = "SELECT generate_series(1, 5) AS n"
      assert {:ok, result} = Executor.execute(ds, sql)
      assert result.row_count == 5
      assert length(result.rows) == 5
    end

    test "blocks INSERT statements", %{data_source: ds} do
      assert {:error, :blocked, msg} =
               Executor.execute(ds, "INSERT INTO users (id) VALUES (gen_random_uuid())")

      assert msg =~ "INSERT"
    end

    test "returns execution error for nonexistent table", %{data_source: ds} do
      assert {:error, :execution, msg} =
               Executor.execute(ds, "SELECT * FROM nonexistent_table_xyz_12345")

      assert msg =~ "nonexistent_table_xyz_12345"
    end

    test "truncates rows to default limit", %{data_source: ds} do
      sql = "SELECT generate_series(1, 1500) AS n"
      assert {:ok, result} = Executor.execute(ds, sql)
      assert result.row_count == 1500
      assert length(result.rows) == 1000
    end

    test "respects custom row_limit option", %{data_source: ds} do
      sql = "SELECT generate_series(1, 100) AS n"
      assert {:ok, result} = Executor.execute(ds, sql, row_limit: 10)
      assert result.row_count == 100
      assert length(result.rows) == 10
    end
  end
end
