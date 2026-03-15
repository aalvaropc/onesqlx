defmodule Onesqlx.DashboardsTest do
  use Onesqlx.DataCase, async: true

  alias Onesqlx.Dashboards

  import Onesqlx.AccountsFixtures
  import Onesqlx.DataSourcesFixtures
  import Onesqlx.SavedQueriesFixtures
  import Onesqlx.DashboardsFixtures

  setup do
    scope = user_scope_fixture()
    %{scope: scope}
  end

  describe "create_dashboard/2" do
    test "creates with valid attributes", %{scope: scope} do
      attrs = valid_dashboard_attributes(%{title: "My Dashboard"})
      assert {:ok, dashboard} = Dashboards.create_dashboard(scope, attrs)
      assert dashboard.title == "My Dashboard"
      assert dashboard.workspace_id == scope.workspace.id
      assert dashboard.user_id == scope.user.id
    end

    test "requires title", %{scope: scope} do
      assert {:error, changeset} = Dashboards.create_dashboard(scope, %{})
      assert errors_on(changeset).title
    end

    test "enforces unique title per workspace", %{scope: scope} do
      dashboard_fixture(scope, %{title: "Duplicate"})
      assert {:error, changeset} = Dashboards.create_dashboard(scope, %{title: "Duplicate"})
      assert "has already been taken" in errors_on(changeset).title
    end

    test "allows same title in different workspaces", %{scope: scope} do
      dashboard_fixture(scope, %{title: "Shared Title"})
      other_scope = user_scope_fixture()
      assert {:ok, _} = Dashboards.create_dashboard(other_scope, %{title: "Shared Title"})
    end

    test "sets user_id from scope", %{scope: scope} do
      {:ok, dashboard} = Dashboards.create_dashboard(scope, valid_dashboard_attributes())
      assert dashboard.user_id == scope.user.id
    end
  end

  describe "list_dashboards/1" do
    test "returns dashboards ordered by updated_at desc", %{scope: scope} do
      d1 = dashboard_fixture(scope, %{title: "Older"})
      d2 = dashboard_fixture(scope, %{title: "Newer"})

      past = DateTime.add(DateTime.utc_now(:second), -60, :second)

      Repo.update_all(
        from(d in Dashboards.Dashboard, where: d.id == ^d1.id),
        set: [updated_at: past]
      )

      result = Dashboards.list_dashboards(scope)
      assert [first, second] = result
      assert first.id == d2.id
      assert second.id == d1.id
    end

    test "enforces workspace isolation", %{scope: scope} do
      dashboard_fixture(scope, %{title: "Visible"})
      other_scope = user_scope_fixture()
      assert Dashboards.list_dashboards(other_scope) == []
    end
  end

  describe "get_dashboard!/2" do
    test "returns the dashboard scoped to workspace", %{scope: scope} do
      dashboard = dashboard_fixture(scope)
      found = Dashboards.get_dashboard!(scope, dashboard.id)
      assert found.id == dashboard.id
    end

    test "raises for dashboard in different workspace", %{scope: scope} do
      dashboard = dashboard_fixture(scope)
      other_scope = user_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Dashboards.get_dashboard!(other_scope, dashboard.id)
      end
    end
  end

  describe "update_dashboard/3" do
    test "updates title and description", %{scope: scope} do
      dashboard = dashboard_fixture(scope)

      assert {:ok, updated} =
               Dashboards.update_dashboard(scope, dashboard, %{
                 title: "Updated Title",
                 description: "New description"
               })

      assert updated.title == "Updated Title"
      assert updated.description == "New description"
    end

    test "rejects blank title", %{scope: scope} do
      dashboard = dashboard_fixture(scope)
      assert {:error, changeset} = Dashboards.update_dashboard(scope, dashboard, %{title: ""})
      assert errors_on(changeset).title
    end
  end

  describe "delete_dashboard/2" do
    test "deletes the dashboard", %{scope: scope} do
      dashboard = dashboard_fixture(scope)
      assert {:ok, _} = Dashboards.delete_dashboard(scope, dashboard)

      assert_raise Ecto.NoResultsError, fn ->
        Dashboards.get_dashboard!(scope, dashboard.id)
      end
    end
  end

  describe "change_dashboard/2" do
    test "returns a changeset" do
      changeset = Dashboards.change_dashboard(%Dashboards.Dashboard{})
      assert %Ecto.Changeset{} = changeset
    end
  end

  describe "add_card/3" do
    setup %{scope: scope} do
      data_source = data_source_fixture(scope)
      saved_query = saved_query_fixture(scope, data_source)
      dashboard = dashboard_fixture(scope)
      %{data_source: data_source, saved_query: saved_query, dashboard: dashboard}
    end

    test "first card gets position 0", %{scope: scope, dashboard: dashboard} do
      {:ok, card} = Dashboards.add_card(scope, dashboard, %{type: "table"})
      assert card.position == 0
    end

    test "second card gets position 1", %{scope: scope, dashboard: dashboard} do
      {:ok, _c1} = Dashboards.add_card(scope, dashboard, %{type: "table"})
      {:ok, c2} = Dashboards.add_card(scope, dashboard, %{type: "kpi"})
      assert c2.position == 1
    end

    test "validates type inclusion", %{scope: scope, dashboard: dashboard} do
      assert {:error, changeset} = Dashboards.add_card(scope, dashboard, %{type: "pie"})
      assert errors_on(changeset).type
    end

    test "accepts all valid types", %{scope: scope, dashboard: dashboard} do
      for type <- ~w(table kpi bar line) do
        assert {:ok, card} = Dashboards.add_card(scope, dashboard, %{type: type})
        assert card.type == type
      end
    end
  end

  describe "remove_card/2" do
    setup %{scope: scope} do
      data_source = data_source_fixture(scope)
      saved_query = saved_query_fixture(scope, data_source)
      dashboard = dashboard_fixture(scope)
      %{data_source: data_source, saved_query: saved_query, dashboard: dashboard}
    end

    test "deletes the card", %{scope: scope, dashboard: dashboard, saved_query: saved_query} do
      card = card_fixture(scope, dashboard, saved_query)
      assert {:ok, _} = Dashboards.remove_card(scope, card)

      d = Dashboards.get_dashboard_with_cards!(scope, dashboard.id)
      assert d.cards == []
    end
  end

  describe "update_card/3" do
    setup %{scope: scope} do
      data_source = data_source_fixture(scope)
      saved_query = saved_query_fixture(scope, data_source)
      dashboard = dashboard_fixture(scope)
      %{data_source: data_source, saved_query: saved_query, dashboard: dashboard}
    end

    test "updates type and title", %{scope: scope, dashboard: dashboard, saved_query: saved_query} do
      card = card_fixture(scope, dashboard, saved_query)

      assert {:ok, updated} =
               Dashboards.update_card(scope, card, %{type: "bar", title: "My Bar Chart"})

      assert updated.type == "bar"
      assert updated.title == "My Bar Chart"
    end
  end

  describe "move_card_up/2" do
    setup %{scope: scope} do
      data_source = data_source_fixture(scope)
      saved_query = saved_query_fixture(scope, data_source)
      dashboard = dashboard_fixture(scope)
      %{data_source: data_source, saved_query: saved_query, dashboard: dashboard}
    end

    test "swaps positions with preceding card", %{
      scope: scope,
      dashboard: dashboard,
      saved_query: saved_query
    } do
      c1 = card_fixture(scope, dashboard, saved_query)
      c2 = card_fixture(scope, dashboard, saved_query)

      assert c1.position == 0
      assert c2.position == 1

      {:ok, _} = Dashboards.move_card_up(scope, c2)

      d = Dashboards.get_dashboard_with_cards!(scope, dashboard.id)
      [first, second] = d.cards
      assert first.id == c2.id
      assert second.id == c1.id
    end

    test "no-op when card is already first", %{
      scope: scope,
      dashboard: dashboard,
      saved_query: saved_query
    } do
      card = card_fixture(scope, dashboard, saved_query)
      assert {:ok, ^card} = Dashboards.move_card_up(scope, card)
    end
  end

  describe "move_card_down/2" do
    setup %{scope: scope} do
      data_source = data_source_fixture(scope)
      saved_query = saved_query_fixture(scope, data_source)
      dashboard = dashboard_fixture(scope)
      %{data_source: data_source, saved_query: saved_query, dashboard: dashboard}
    end

    test "swaps positions with following card", %{
      scope: scope,
      dashboard: dashboard,
      saved_query: saved_query
    } do
      c1 = card_fixture(scope, dashboard, saved_query)
      c2 = card_fixture(scope, dashboard, saved_query)

      assert c1.position == 0
      assert c2.position == 1

      {:ok, _} = Dashboards.move_card_down(scope, c1)

      d = Dashboards.get_dashboard_with_cards!(scope, dashboard.id)
      [first, second] = d.cards
      assert first.id == c2.id
      assert second.id == c1.id
    end

    test "no-op when card is already last", %{
      scope: scope,
      dashboard: dashboard,
      saved_query: saved_query
    } do
      card = card_fixture(scope, dashboard, saved_query)
      assert {:ok, ^card} = Dashboards.move_card_down(scope, card)
    end
  end

  describe "get_dashboard_with_cards!/2" do
    setup %{scope: scope} do
      data_source = data_source_fixture(scope)
      saved_query = saved_query_fixture(scope, data_source)
      dashboard = dashboard_fixture(scope)
      %{data_source: data_source, saved_query: saved_query, dashboard: dashboard}
    end

    test "cards are ordered by position", %{
      scope: scope,
      dashboard: dashboard,
      saved_query: saved_query
    } do
      c1 = card_fixture(scope, dashboard, saved_query)
      c2 = card_fixture(scope, dashboard, saved_query)

      d = Dashboards.get_dashboard_with_cards!(scope, dashboard.id)
      assert [first, second] = d.cards
      assert first.id == c1.id
      assert second.id == c2.id
    end

    test "preloads saved_query and data_source", %{
      scope: scope,
      dashboard: dashboard,
      saved_query: saved_query,
      data_source: data_source
    } do
      card_fixture(scope, dashboard, saved_query)

      d = Dashboards.get_dashboard_with_cards!(scope, dashboard.id)
      [card] = d.cards
      assert card.saved_query.id == saved_query.id
      assert card.saved_query.data_source.id == data_source.id
    end

    test "cascades delete to cards when dashboard is deleted", %{
      scope: scope,
      dashboard: dashboard,
      saved_query: saved_query
    } do
      card_fixture(scope, dashboard, saved_query)
      {:ok, _} = Dashboards.delete_dashboard(scope, dashboard)

      assert Repo.all(Onesqlx.Dashboards.DashboardCard) == []
    end
  end
end
