defmodule Onesqlx.Querying.ExecutorReadOnlyTest do
  use Onesqlx.DataCase, async: true

  import Mox
  import Onesqlx.AccountsFixtures
  import Onesqlx.DataSourcesFixtures

  alias Onesqlx.DataSources.MockConnection
  alias Onesqlx.Querying.Executor

  setup :verify_on_exit!

  setup do
    %{scope: user_scope_fixture()}
  end

  describe "SQL guard vs the read_only flag" do
    test "read-only data sources (default) block write SQL before connecting", %{scope: scope} do
      ds = data_source_fixture(scope)
      assert ds.read_only

      assert {:error, :blocked, msg} = Executor.execute(ds, "DELETE FROM accounts")
      assert msg =~ "DELETE"
    end

    test "writable data sources skip the guard and reach the connection", %{scope: scope} do
      ds = data_source_fixture(scope, %{name: "writable-db", read_only: false})
      refute ds.read_only

      stub(MockConnection, :with_connection, fn _ds, _fun ->
        {:error, :execution, "reached connection"}
      end)

      assert {:error, :execution, "reached connection"} =
               Executor.execute(ds, "DELETE FROM accounts")
    end

    test "explain honors the same flag", %{scope: scope} do
      read_only_ds = data_source_fixture(scope, %{name: "ro-db"})
      writable_ds = data_source_fixture(scope, %{name: "rw-db", read_only: false})

      assert {:error, :blocked, _} = Executor.explain(read_only_ds, "UPDATE t SET x = 1")

      stub(MockConnection, :with_connection, fn _ds, _fun ->
        {:ok, "Update on t"}
      end)

      assert {:ok, "Update on t"} = Executor.explain(writable_ds, "UPDATE t SET x = 1")
    end
  end
end
