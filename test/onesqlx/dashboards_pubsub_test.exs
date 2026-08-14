defmodule Onesqlx.DashboardsPubsubTest do
  use Onesqlx.DataCase, async: true

  import Onesqlx.AccountsFixtures
  import Onesqlx.DashboardsFixtures

  alias Onesqlx.Dashboards

  setup do
    scope = user_scope_fixture()
    dashboard = dashboard_fixture(scope)
    :ok = Dashboards.subscribe(dashboard.id)
    %{scope: scope, dashboard: dashboard}
  end

  test "card mutations broadcast to other subscribers", %{scope: scope, dashboard: dashboard} do
    # Mutate from another process: the test process must receive the event
    Task.async(fn -> Dashboards.add_card(scope, dashboard, %{type: "table"}) end)
    |> Task.await()

    dashboard_id = dashboard.id
    assert_receive {:dashboard_updated, ^dashboard_id}
  end

  test "variable updates broadcast", %{scope: scope, dashboard: dashboard} do
    Task.async(fn ->
      Dashboards.update_variables(scope, dashboard, [%{"name" => "region"}])
    end)
    |> Task.await()

    dashboard_id = dashboard.id
    assert_receive {:dashboard_updated, ^dashboard_id}
  end

  test "the mutating process is excluded from the broadcast", %{
    scope: scope,
    dashboard: dashboard
  } do
    {:ok, _} = Dashboards.add_card(scope, dashboard, %{type: "table"})

    refute_receive {:dashboard_updated, _}, 100
  end

  test "failed mutations do not broadcast", %{scope: scope, dashboard: dashboard} do
    Task.async(fn ->
      {:error, _} = Dashboards.update_variables(scope, dashboard, [%{"name" => "bad name!"}])
    end)
    |> Task.await()

    refute_receive {:dashboard_updated, _}, 100
  end
end
