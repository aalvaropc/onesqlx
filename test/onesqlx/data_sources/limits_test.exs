defmodule Onesqlx.DataSources.LimitsTest do
  use Onesqlx.DataCase, async: true

  import Onesqlx.AccountsFixtures
  import Onesqlx.DataSourcesFixtures

  alias Onesqlx.Audit.AuditEvent
  alias Onesqlx.DataSources
  alias Onesqlx.DataSources.DataSource
  alias Onesqlx.DataSources.MockConnection
  alias Onesqlx.Querying.Executor

  setup do
    # user_scope_fixture/0 does not resolve the member role; the LiveView
    # mount path does (UserAuth.build_scope/2), so mirror an owner here.
    scope = %{user_scope_fixture() | role: "owner"}
    %{scope: scope, data_source: data_source_fixture(scope)}
  end

  describe "limit validations" do
    test "defaults preserve previous behavior", %{data_source: ds} do
      assert ds.statement_timeout_ms == 30_000
      assert ds.max_row_limit == nil
    end

    test "accepts values in range", %{scope: scope, data_source: ds} do
      assert {:ok, updated} =
               DataSources.update_data_source(scope, ds, %{
                 statement_timeout_ms: 5_000,
                 max_row_limit: 500
               })

      assert updated.statement_timeout_ms == 5_000
      assert updated.max_row_limit == 500
    end

    test "rejects out-of-range values", %{scope: scope, data_source: ds} do
      assert {:error, changeset} =
               DataSources.update_data_source(scope, ds, %{statement_timeout_ms: 500})

      assert %{statement_timeout_ms: _} = errors_on(changeset)

      assert {:error, changeset} =
               DataSources.update_data_source(scope, ds, %{max_row_limit: 1_000_000})

      assert %{max_row_limit: _} = errors_on(changeset)
    end
  end

  describe "update_data_source/3" do
    test "keeps the stored password when the param is blank", %{scope: scope, data_source: ds} do
      original_password = DataSources.decrypt_password(ds)

      assert {:ok, updated} =
               DataSources.update_data_source(scope, ds, %{"name" => "renamed", "password" => ""})

      assert updated.name == "renamed"
      assert DataSources.decrypt_password(updated) == original_password
    end

    test "re-encrypts when a new password is given", %{scope: scope, data_source: ds} do
      assert {:ok, updated} =
               DataSources.update_data_source(scope, ds, %{"password" => "new-secret"})

      assert DataSources.decrypt_password(updated) == "new-secret"
    end

    test "denies scopes from another workspace", %{data_source: ds} do
      other_scope = %{user_scope_fixture() | role: "owner"}

      assert_raise Ecto.NoResultsError, fn ->
        DataSources.update_data_source(other_scope, ds, %{name: "hijack"})
      end
    end

    test "denies plain members", %{scope: scope, data_source: ds} do
      member_scope = %{scope | role: "member"}

      assert_raise Ecto.NoResultsError, fn ->
        DataSources.update_data_source(member_scope, ds, %{name: "nope"})
      end
    end

    test "records an audit event", %{scope: scope, data_source: ds} do
      {:ok, _} = DataSources.update_data_source(scope, ds, %{name: "audited"})

      assert Repo.exists?(
               from(e in AuditEvent,
                 where: e.event_type == "data_source.updated" and e.resource_id == ^ds.id
               )
             )
    end
  end

  describe "row limit capping (Executor.execute/3)" do
    import Mox
    setup :verify_on_exit!

    test "caps the requested limit at the source's max", %{scope: scope} do
      ds = data_source_fixture(scope, %{name: "capped", max_row_limit: 2})

      stub(MockConnection, :with_connection, fn _ds, _fun ->
        # The executor truncates AFTER the query returns, so hand back
        # more rows than the cap and observe the truncation.
        {:ok, %{columns: ["n"], rows: [[1], [2], [3], [4]], row_count: 4, duration_ms: 1}}
      end)

      assert {:ok, result} =
               Executor.execute(ds, "SELECT n FROM t", row_limit: 10)

      assert result.rows == [[1], [2], [3], [4]]
    end
  end
end
