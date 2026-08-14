defmodule Onesqlx.DashboardsVariablesTest do
  use Onesqlx.DataCase, async: true

  import Onesqlx.AccountsFixtures
  import Onesqlx.DashboardsFixtures

  alias Onesqlx.Dashboards

  setup do
    scope = user_scope_fixture()
    %{scope: scope, dashboard: dashboard_fixture(scope)}
  end

  describe "update_variables/3" do
    test "stores normalized variables", %{scope: scope, dashboard: dashboard} do
      variables = [
        %{"name" => "category", "type" => "text", "default" => "books"},
        %{"name" => "min_total", "type" => "number"}
      ]

      assert {:ok, updated} = Dashboards.update_variables(scope, dashboard, variables)

      assert [
               %{"name" => "category", "type" => "text", "default" => "books"},
               %{"name" => "min_total", "type" => "number", "default" => nil}
             ] = updated.variables
    end

    test "defaults the type to text", %{scope: scope, dashboard: dashboard} do
      assert {:ok, updated} =
               Dashboards.update_variables(scope, dashboard, [%{"name" => "region"}])

      assert [%{"type" => "text"}] = updated.variables
    end

    test "rejects invalid identifiers", %{scope: scope, dashboard: dashboard} do
      assert {:error, changeset} =
               Dashboards.update_variables(scope, dashboard, [%{"name" => "bad name!"}])

      assert %{variables: [msg]} = errors_on(changeset)
      assert msg =~ "valid identifiers"
    end

    test "rejects unknown types", %{scope: scope, dashboard: dashboard} do
      assert {:error, changeset} =
               Dashboards.update_variables(scope, dashboard, [
                 %{"name" => "x", "type" => "boolean"}
               ])

      assert %{variables: [msg]} = errors_on(changeset)
      assert msg =~ "must be one of"
    end

    test "rejects duplicate names", %{scope: scope, dashboard: dashboard} do
      assert {:error, changeset} =
               Dashboards.update_variables(scope, dashboard, [
                 %{"name" => "x"},
                 %{"name" => "x"}
               ])

      assert %{variables: [msg]} = errors_on(changeset)
      assert msg =~ "unique"
    end

    test "a scope from another workspace cannot manage the variables", %{dashboard: dashboard} do
      other_scope = user_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Dashboards.update_variables(other_scope, dashboard, [%{"name" => "x"}])
      end
    end
  end

  describe "variable_defaults/1" do
    test "returns only non-empty defaults", %{scope: scope, dashboard: dashboard} do
      {:ok, updated} =
        Dashboards.update_variables(scope, dashboard, [
          %{"name" => "a", "default" => "1"},
          %{"name" => "b", "default" => ""},
          %{"name" => "c"}
        ])

      assert Dashboards.variable_defaults(updated) == %{"a" => "1"}
    end
  end
end
