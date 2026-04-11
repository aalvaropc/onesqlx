defmodule Onesqlx.AuthorizationTest do
  use Onesqlx.DataCase, async: true

  alias Onesqlx.Authorization

  import Onesqlx.AccountsFixtures
  import Onesqlx.DataSourcesFixtures
  import Onesqlx.SavedQueriesFixtures

  describe "can_manage?/2" do
    test "owner can manage any resource" do
      scope = user_scope_fixture()
      scope = %{scope | role: "owner"}
      ds = data_source_fixture(scope)
      sq = saved_query_fixture(scope, ds)

      other_scope = user_scope_fixture()
      other_scope = %{other_scope | role: "owner"}
      other_ds = data_source_fixture(other_scope)
      other_sq = saved_query_fixture(other_scope, other_ds)

      assert Authorization.can_manage?(scope, sq)
      assert Authorization.can_manage?(scope, other_sq)
    end

    test "admin can manage any resource" do
      scope = user_scope_fixture()
      scope = %{scope | role: "admin"}
      ds = data_source_fixture(scope)
      sq = saved_query_fixture(scope, ds)

      assert Authorization.can_manage?(scope, sq)
    end

    test "member can manage own resource" do
      scope = user_scope_fixture()
      scope = %{scope | role: "member"}
      ds = data_source_fixture(scope)
      sq = saved_query_fixture(scope, ds)

      assert Authorization.can_manage?(scope, sq)
    end

    test "member cannot manage another user's resource" do
      scope = user_scope_fixture()
      scope = %{scope | role: "member"}

      other_scope = user_scope_fixture()
      other_ds = data_source_fixture(other_scope)
      other_sq = saved_query_fixture(other_scope, other_ds)

      refute Authorization.can_manage?(scope, other_sq)
    end
  end

  describe "authorize_manage!/2" do
    test "raises for unauthorized member" do
      scope = user_scope_fixture()
      scope = %{scope | role: "member"}

      other_scope = user_scope_fixture()
      other_ds = data_source_fixture(other_scope)
      other_sq = saved_query_fixture(other_scope, other_ds)

      assert_raise Ecto.NoResultsError, fn ->
        Authorization.authorize_manage!(scope, other_sq)
      end
    end

    test "returns resource for authorized user" do
      scope = user_scope_fixture()
      scope = %{scope | role: "admin"}
      ds = data_source_fixture(scope)
      sq = saved_query_fixture(scope, ds)

      assert Authorization.authorize_manage!(scope, sq) == sq
    end
  end
end
