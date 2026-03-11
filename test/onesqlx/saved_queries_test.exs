defmodule Onesqlx.SavedQueriesTest do
  use Onesqlx.DataCase, async: true

  alias Onesqlx.SavedQueries

  import Onesqlx.AccountsFixtures
  import Onesqlx.DataSourcesFixtures
  import Onesqlx.SavedQueriesFixtures

  setup do
    scope = user_scope_fixture()
    data_source = data_source_fixture(scope)
    %{scope: scope, data_source: data_source}
  end

  describe "create_saved_query/2" do
    test "creates with valid attributes", %{scope: scope, data_source: data_source} do
      attrs = valid_saved_query_attributes(scope, data_source, %{title: "My Query"})
      assert {:ok, saved_query} = SavedQueries.create_saved_query(scope, attrs)
      assert saved_query.title == "My Query"
      assert saved_query.sql == "SELECT 1"
      assert saved_query.workspace_id == scope.workspace.id
      assert saved_query.user_id == scope.user.id
      assert saved_query.data_source_id == data_source.id
      assert saved_query.is_favorite == false
      assert saved_query.tags == []
    end

    test "requires title and sql", %{scope: scope} do
      assert {:error, changeset} = SavedQueries.create_saved_query(scope, %{})
      errors = errors_on(changeset)
      assert errors.title
      assert errors.sql
    end

    test "enforces unique title per workspace", %{scope: scope, data_source: data_source} do
      saved_query_fixture(scope, data_source, %{title: "Duplicate"})

      attrs = valid_saved_query_attributes(scope, data_source, %{title: "Duplicate"})
      assert {:error, changeset} = SavedQueries.create_saved_query(scope, attrs)
      assert "has already been taken" in errors_on(changeset).title
    end

    test "allows same title in different workspaces", %{data_source: data_source, scope: scope} do
      saved_query_fixture(scope, data_source, %{title: "Shared Title"})

      other_scope = user_scope_fixture()
      other_ds = data_source_fixture(other_scope)

      attrs = valid_saved_query_attributes(other_scope, other_ds, %{title: "Shared Title"})
      assert {:ok, _} = SavedQueries.create_saved_query(other_scope, attrs)
    end

    test "saves tags", %{scope: scope, data_source: data_source} do
      attrs = valid_saved_query_attributes(scope, data_source, %{tags: ["analytics", "daily"]})
      assert {:ok, saved_query} = SavedQueries.create_saved_query(scope, attrs)
      assert saved_query.tags == ["analytics", "daily"]
    end
  end

  describe "list_saved_queries/2" do
    test "returns saved queries ordered by updated_at desc", %{
      scope: scope,
      data_source: data_source
    } do
      q1 = saved_query_fixture(scope, data_source, %{title: "First"})
      q2 = saved_query_fixture(scope, data_source, %{title: "Second"})

      # Touch q1 to make it most recently updated
      {:ok, _} = SavedQueries.update_saved_query(scope, q1, %{description: "updated"})

      result = SavedQueries.list_saved_queries(scope)
      assert [first, second] = result
      assert first.title == "First"
      assert second.title == "Second"
      assert first.id == q1.id
      assert second.id == q2.id
    end

    test "enforces workspace isolation", %{scope: scope, data_source: data_source} do
      saved_query_fixture(scope, data_source, %{title: "Visible"})

      other_scope = user_scope_fixture()
      assert SavedQueries.list_saved_queries(other_scope) == []
    end

    test "filters by search term (case-insensitive)", %{
      scope: scope,
      data_source: data_source
    } do
      saved_query_fixture(scope, data_source, %{title: "Sales Report"})
      saved_query_fixture(scope, data_source, %{title: "User Activity"})

      result = SavedQueries.list_saved_queries(scope, search: "sales")
      assert length(result) == 1
      assert hd(result).title == "Sales Report"
    end

    test "filters by favorites only", %{scope: scope, data_source: data_source} do
      saved_query_fixture(scope, data_source, %{title: "Favorite", is_favorite: true})
      saved_query_fixture(scope, data_source, %{title: "Normal", is_favorite: false})

      result = SavedQueries.list_saved_queries(scope, favorites_only: true)
      assert length(result) == 1
      assert hd(result).title == "Favorite"
    end

    test "filters by data source", %{scope: scope, data_source: data_source} do
      other_ds = data_source_fixture(scope, %{name: "other-ds"})

      saved_query_fixture(scope, data_source, %{title: "DS1 Query"})
      saved_query_fixture(scope, other_ds, %{title: "DS2 Query"})

      result = SavedQueries.list_saved_queries(scope, data_source_id: data_source.id)
      assert length(result) == 1
      assert hd(result).title == "DS1 Query"
    end

    test "filters by tag", %{scope: scope, data_source: data_source} do
      saved_query_fixture(scope, data_source, %{title: "Tagged", tags: ["analytics", "daily"]})
      saved_query_fixture(scope, data_source, %{title: "Untagged", tags: []})

      result = SavedQueries.list_saved_queries(scope, tag: "analytics")
      assert length(result) == 1
      assert hd(result).title == "Tagged"
    end

    test "preloads data_source", %{scope: scope, data_source: data_source} do
      saved_query_fixture(scope, data_source)

      [query] = SavedQueries.list_saved_queries(scope)
      assert query.data_source.id == data_source.id
      assert query.data_source.name == data_source.name
    end
  end

  describe "get_saved_query!/2" do
    test "returns the saved query scoped to workspace", %{
      scope: scope,
      data_source: data_source
    } do
      saved_query = saved_query_fixture(scope, data_source)
      found = SavedQueries.get_saved_query!(scope, saved_query.id)
      assert found.id == saved_query.id
    end

    test "raises for query in different workspace", %{scope: scope, data_source: data_source} do
      saved_query = saved_query_fixture(scope, data_source)
      other_scope = user_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        SavedQueries.get_saved_query!(other_scope, saved_query.id)
      end
    end

    test "preloads data_source", %{scope: scope, data_source: data_source} do
      saved_query = saved_query_fixture(scope, data_source)
      found = SavedQueries.get_saved_query!(scope, saved_query.id)
      assert found.data_source.id == data_source.id
    end
  end

  describe "update_saved_query/3" do
    test "updates title and description", %{scope: scope, data_source: data_source} do
      saved_query = saved_query_fixture(scope, data_source)

      assert {:ok, updated} =
               SavedQueries.update_saved_query(scope, saved_query, %{
                 title: "Updated Title",
                 description: "New description"
               })

      assert updated.title == "Updated Title"
      assert updated.description == "New description"
    end

    test "rejects blank title", %{scope: scope, data_source: data_source} do
      saved_query = saved_query_fixture(scope, data_source)

      assert {:error, changeset} =
               SavedQueries.update_saved_query(scope, saved_query, %{title: ""})

      assert errors_on(changeset).title
    end
  end

  describe "delete_saved_query/2" do
    test "deletes the saved query", %{scope: scope, data_source: data_source} do
      saved_query = saved_query_fixture(scope, data_source)
      assert {:ok, _} = SavedQueries.delete_saved_query(scope, saved_query)

      assert_raise Ecto.NoResultsError, fn ->
        SavedQueries.get_saved_query!(scope, saved_query.id)
      end
    end
  end

  describe "toggle_favorite/2" do
    test "toggles is_favorite from false to true and back", %{
      scope: scope,
      data_source: data_source
    } do
      saved_query = saved_query_fixture(scope, data_source, %{is_favorite: false})

      assert {:ok, toggled} = SavedQueries.toggle_favorite(scope, saved_query)
      assert toggled.is_favorite == true

      assert {:ok, toggled_back} = SavedQueries.toggle_favorite(scope, toggled)
      assert toggled_back.is_favorite == false
    end
  end

  describe "change_saved_query/2" do
    test "returns a changeset" do
      changeset = SavedQueries.change_saved_query(%SavedQueries.SavedQuery{})
      assert %Ecto.Changeset{} = changeset
    end
  end
end
