defmodule Onesqlx.Querying.ExecutorExplainTest do
  use Onesqlx.DataCase, async: true

  import Mox
  import Onesqlx.AccountsFixtures
  import Onesqlx.DataSourcesFixtures

  alias Onesqlx.DataSources.MockConnection
  alias Onesqlx.Querying.Executor

  setup :verify_on_exit!

  setup do
    scope = user_scope_fixture()
    data_source = data_source_fixture(scope)
    %{data_source: data_source}
  end

  describe "explain/3" do
    test "returns plan text on success", %{data_source: ds} do
      stub(MockConnection, :with_connection, fn _ds, _fun ->
        {:ok,
         "Seq Scan on employees  (cost=0.00..1.10 rows=10 width=100) (actual time=0.01..0.02 rows=10 loops=1)\nPlanning Time: 0.05 ms\nExecution Time: 0.03 ms"}
      end)

      assert {:ok, plan} = Executor.explain(ds, "SELECT * FROM employees")
      assert plan =~ "Seq Scan"
      assert plan =~ "Planning Time"
    end

    test "returns error for blocked SQL", %{data_source: ds} do
      assert {:error, :blocked, msg} = Executor.explain(ds, "INSERT INTO users VALUES (1)")
      assert msg =~ "INSERT"
    end

    test "returns error for non-string input" do
      assert {:error, :blocked, _} = Executor.explain(%Onesqlx.DataSources.DataSource{}, 123)
    end
  end
end
