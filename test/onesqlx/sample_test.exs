defmodule Onesqlx.SampleTest do
  use Onesqlx.DataCase, async: false
  use Oban.Testing, repo: Onesqlx.Repo

  import Onesqlx.AccountsFixtures

  alias Onesqlx.Catalog.SyncWorker
  alias Onesqlx.Dashboards
  alias Onesqlx.DataSources
  alias Onesqlx.Sample
  alias Onesqlx.SavedQueries

  setup do
    %{scope: user_scope_fixture()}
  end

  describe "install/2" do
    test "creates the data source, saved queries, and dashboard", %{scope: scope} do
      assert {:ok, result} = Sample.install(scope, sync_catalog: false)

      assert result.data_source.name == "Sample Data"
      assert result.data_source.username == "onesqlx_sample"
      assert result.data_source.read_only
      assert map_size(result.queries) == 5

      assert [data_source] = DataSources.list_data_sources(scope)
      assert data_source.id == result.data_source.id

      titles = scope |> SavedQueries.list_saved_queries() |> Enum.map(& &1.title) |> Enum.sort()
      assert "Total revenue" in titles
      assert "Revenue by month" in titles
      assert length(titles) == 5

      dashboard = Dashboards.get_dashboard_with_cards!(scope, result.dashboard.id)
      assert length(dashboard.cards) == 5
      assert Enum.map(dashboard.cards, & &1.type) |> Enum.sort() == ~w(bar kpi line pie table)
    end

    test "populates the sample schema with data", %{scope: scope} do
      assert {:ok, _} = Sample.install(scope, sync_catalog: false)

      assert count("products") == 40
      assert count("customers") == 150
      assert count("orders") == 1200
      assert count("order_items") > 1200

      # The dataset is deterministic, so the demo looks the same everywhere
      %{rows: [[revenue]]} =
        Repo.query!("""
        SELECT round(sum(oi.quantity * oi.unit_price), 2)
        FROM onesqlx_sample.order_items oi
        JOIN onesqlx_sample.orders o ON o.id = oi.order_id
        WHERE o.status IN ('delivered', 'shipped')
        """)

      assert Decimal.gt?(revenue, 0)
    end

    test "is idempotent", %{scope: scope} do
      assert {:ok, _} = Sample.install(scope, sync_catalog: false)
      assert {:ok, :already_installed} = Sample.install(scope, sync_catalog: false)
      assert length(DataSources.list_data_sources(scope)) == 1
    end

    test "enqueues a catalog sync by default", %{scope: scope} do
      assert {:ok, result} = Sample.install(scope)
      assert_enqueued(worker: SyncWorker, args: %{"data_source_id" => result.data_source.id})
    end

    test "the saved queries run against the sample data", %{scope: scope} do
      assert {:ok, result} = Sample.install(scope, sync_catalog: false)

      # Executed through the app's own connection rather than the data
      # source, which is enough to prove the SQL itself is valid.
      for {_key, query} <- result.queries do
        assert %Postgrex.Result{} = Repo.query!(String.trim_trailing(query.sql, ";"))
      end
    end
  end

  describe "credential isolation" do
    setup %{scope: scope} do
      {:ok, _} = Sample.install(scope, sync_catalog: false)
      :ok
    end

    test "the sample role can only read the sample schema" do
      assert granted?("has_schema_privilege('onesqlx_sample', 'onesqlx_sample', 'USAGE')")
      assert granted?("has_table_privilege('onesqlx_sample', 'onesqlx_sample.orders', 'SELECT')")
    end

    test "the sample role cannot read application tables" do
      # The data source points at OneSQLx's own database, so this is the
      # property that keeps it from being an escalation path: Ecto tables
      # grant nothing to other roles.
      for table <- ~w(users users_tokens api_tokens data_sources workspaces) do
        refute granted?("has_table_privilege('onesqlx_sample', '#{table}', 'SELECT')"),
               "the sample role should not be able to SELECT from #{table}"
      end
    end

    test "the sample role cannot write to the sample schema" do
      refute granted?("has_table_privilege('onesqlx_sample', 'onesqlx_sample.orders', 'INSERT')")
      refute granted?("has_schema_privilege('onesqlx_sample', 'onesqlx_sample', 'CREATE')")
    end
  end

  describe "installed?/1" do
    test "is false before installing and true after", %{scope: scope} do
      refute Sample.installed?(scope)
      assert {:ok, _} = Sample.install(scope, sync_catalog: false)
      assert Sample.installed?(scope)
    end
  end

  defp granted?(expression) do
    %{rows: [[result]]} = Repo.query!("SELECT #{expression}")
    result
  end

  defp count(table) do
    %{rows: [[count]]} = Repo.query!("SELECT count(*) FROM onesqlx_sample.#{table}")
    count
  end
end
