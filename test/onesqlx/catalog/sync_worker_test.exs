defmodule Onesqlx.Catalog.SyncWorkerTest do
  use Onesqlx.DataCase, async: true
  use Oban.Testing, repo: Onesqlx.Repo

  alias Onesqlx.Catalog
  alias Onesqlx.Catalog.SyncWorker
  alias Onesqlx.DataSources

  import Onesqlx.AccountsFixtures
  import Onesqlx.DataSourcesFixtures

  @moduletag timeout: 30_000

  setup do
    scope = user_scope_fixture()

    config = test_db_config()

    data_source =
      data_source_fixture(scope, %{
        host: config[:hostname],
        port: config[:port] || 5432,
        database_name: config[:database],
        username: config[:username],
        password: config[:password]
      })

    %{scope: scope, data_source: data_source}
  end

  describe "perform/1" do
    test "syncs catalog and sets status to connected", %{
      scope: scope,
      data_source: data_source
    } do
      assert :ok = perform_job(SyncWorker, %{"data_source_id" => data_source.id})

      data_source = DataSources.get_data_source!(scope, data_source.id)
      assert data_source.status == "connected"

      assert Catalog.synced?(scope, data_source.id)
      stats = Catalog.catalog_stats(scope, data_source.id)
      assert stats.schemas > 0
      assert stats.tables > 0
      assert stats.columns > 0
    end

    test "sets status to error on connection failure", %{scope: scope} do
      bad_source =
        data_source_fixture(scope, %{
          host: "localhost",
          port: 59_999,
          database_name: "nonexistent",
          username: "bad_user",
          password: "bad_password"
        })

      assert {:error, _reason} = perform_job(SyncWorker, %{"data_source_id" => bad_source.id})

      bad_source = DataSources.get_data_source!(scope, bad_source.id)
      assert bad_source.status == "error"
    end
  end

  describe "enqueue/1" do
    test "inserts an Oban job", %{data_source: data_source} do
      assert {:ok, _job} = SyncWorker.enqueue(data_source.id)
      assert_enqueued(worker: SyncWorker, args: %{"data_source_id" => data_source.id})
    end
  end
end
