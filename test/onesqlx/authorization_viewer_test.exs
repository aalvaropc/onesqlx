defmodule Onesqlx.AuthorizationViewerTest do
  use Onesqlx.DataCase, async: true

  import Onesqlx.AccountsFixtures
  import Onesqlx.DataSourcesFixtures
  import Onesqlx.SavedQueriesFixtures

  alias Onesqlx.Accounts.Scope
  alias Onesqlx.Authorization
  alias Onesqlx.Dashboards
  alias Onesqlx.DashboardsFixtures
  alias Onesqlx.DataSources.MockConnection
  alias Onesqlx.Querying
  alias Onesqlx.SavedQueries
  alias Onesqlx.Scheduling
  alias Onesqlx.Snippets
  alias Onesqlx.Workspaces

  setup do
    owner_scope = %{user_scope_fixture() | role: "owner"}
    viewer_scope = %{owner_scope | role: "viewer"}
    %{owner: owner_scope, viewer: viewer_scope}
  end

  describe "authorization matrix" do
    test "viewers manage nothing, even resources carrying their user_id", %{viewer: viewer} do
      refute Authorization.can_manage?(viewer, %{user_id: viewer.user.id})
    end

    test "viewers cannot create; everyone else can", %{owner: owner, viewer: viewer} do
      refute Authorization.can_create?(viewer)
      assert Authorization.can_create?(owner)
      assert Authorization.can_create?(%{owner | role: "admin"})
      assert Authorization.can_create?(%{owner | role: "member"})
    end
  end

  describe "context enforcement" do
    test "every create denies a viewer scope", %{owner: owner, viewer: viewer} do
      assert_raise Ecto.NoResultsError, fn ->
        Dashboards.create_dashboard(viewer, %{title: "nope"})
      end

      assert_raise Ecto.NoResultsError, fn ->
        Onesqlx.DataSources.create_data_source(viewer, %{name: "nope"})
      end

      assert_raise Ecto.NoResultsError, fn ->
        Snippets.create_snippet(viewer, %{"title" => "nope", "sql" => "SELECT 1"})
      end

      ds = data_source_fixture(owner)

      assert_raise Ecto.NoResultsError, fn ->
        SavedQueries.create_saved_query(viewer, %{
          "title" => "nope",
          "sql" => "SELECT 1",
          "data_source_id" => ds.id,
          "user_id" => viewer.user.id
        })
      end

      sq = saved_query_fixture(owner, ds)

      assert_raise Ecto.NoResultsError, fn ->
        Scheduling.create_scheduled_query(viewer, %{
          "name" => "nope",
          "schedule_type" => "daily",
          "saved_query_id" => sq.id
        })
      end
    end

    test "viewers can still execute queries", %{owner: owner, viewer: viewer} do
      import Mox
      ds = data_source_fixture(owner)

      stub(MockConnection, :with_connection, fn _ds, _fun ->
        {:ok, %{columns: ["n"], rows: [[1]], row_count: 1, duration_ms: 1}}
      end)

      assert {:ok, %{rows: [[1]]}} = Querying.execute_query(viewer, ds, "SELECT 1", %{})
    end

    test "the viewer role is accepted by memberships and manage stays denied", %{owner: owner} do
      other = user_fixture()

      assert {:ok, member} =
               Workspaces.add_member(owner.workspace, other, "viewer")

      assert member.role == "viewer"

      assert_raise Ecto.NoResultsError, fn ->
        dashboard = DashboardsFixtures.dashboard_fixture(owner)
        viewer_scope = Scope.for_user(other, owner.workspace, "viewer")
        Dashboards.update_dashboard(viewer_scope, dashboard, %{title: "hijack"})
      end
    end
  end
end
