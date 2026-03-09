defmodule Onesqlx.DataSourcesTest do
  use Onesqlx.DataCase, async: true

  alias Onesqlx.DataSources
  alias Onesqlx.DataSources.DataSource

  import Onesqlx.AccountsFixtures
  import Onesqlx.DataSourcesFixtures

  setup do
    scope = user_scope_fixture()
    %{scope: scope}
  end

  describe "list_data_sources/1" do
    test "returns empty list when no data sources exist", %{scope: scope} do
      assert DataSources.list_data_sources(scope) == []
    end

    test "returns data sources for the workspace ordered by name", %{scope: scope} do
      ds_b = data_source_fixture(scope, %{name: "b-source"})
      ds_a = data_source_fixture(scope, %{name: "a-source"})

      assert [first, second] = DataSources.list_data_sources(scope)
      assert first.id == ds_a.id
      assert second.id == ds_b.id
    end

    test "does not return data sources from other workspaces", %{scope: scope} do
      other_scope = user_scope_fixture()
      data_source_fixture(other_scope, %{name: "other-ds"})

      assert DataSources.list_data_sources(scope) == []
    end
  end

  describe "get_data_source!/2" do
    test "returns the data source with given id", %{scope: scope} do
      ds = data_source_fixture(scope)
      assert DataSources.get_data_source!(scope, ds.id).id == ds.id
    end

    test "raises when data source belongs to another workspace", %{scope: scope} do
      other_scope = user_scope_fixture()
      ds = data_source_fixture(other_scope)

      assert_raise Ecto.NoResultsError, fn ->
        DataSources.get_data_source!(scope, ds.id)
      end
    end
  end

  describe "create_data_source/2" do
    test "creates a data source with valid attributes", %{scope: scope} do
      attrs = valid_data_source_attributes(%{name: "my-db"})
      assert {:ok, %DataSource{} = ds} = DataSources.create_data_source(scope, attrs)
      assert ds.name == "my-db"
      assert ds.host == "localhost"
      assert ds.port == 5432
      assert ds.database_name == "test_db"
      assert ds.username == "postgres"
      assert ds.workspace_id == scope.workspace.id
      assert ds.status == "pending"
      assert ds.adapter == "postgresql"
    end

    test "encrypted_password is not plaintext", %{scope: scope} do
      attrs = valid_data_source_attributes(%{password: "my_secret"})
      {:ok, ds} = DataSources.create_data_source(scope, attrs)
      refute ds.encrypted_password == "my_secret"
      assert is_binary(ds.encrypted_password)
    end

    test "password can be decrypted back", %{scope: scope} do
      attrs = valid_data_source_attributes(%{password: "my_secret"})
      {:ok, ds} = DataSources.create_data_source(scope, attrs)
      assert DataSources.decrypt_password(ds) == "my_secret"
    end

    test "requires password on insert", %{scope: scope} do
      attrs = valid_data_source_attributes() |> Map.delete(:password)
      assert {:error, changeset} = DataSources.create_data_source(scope, attrs)
      assert "can't be blank" in errors_on(changeset).password
    end

    test "requires name", %{scope: scope} do
      attrs = valid_data_source_attributes() |> Map.delete(:name)
      assert {:error, changeset} = DataSources.create_data_source(scope, attrs)
      assert "can't be blank" in errors_on(changeset).name
    end

    test "validates name length", %{scope: scope} do
      attrs = valid_data_source_attributes(%{name: "a"})
      assert {:error, changeset} = DataSources.create_data_source(scope, attrs)
      assert errors_on(changeset).name != []
    end

    test "validates port range", %{scope: scope} do
      attrs = valid_data_source_attributes(%{port: 0})
      assert {:error, changeset} = DataSources.create_data_source(scope, attrs)
      assert errors_on(changeset).port != []

      attrs = valid_data_source_attributes(%{port: 70_000})
      assert {:error, changeset} = DataSources.create_data_source(scope, attrs)
      assert errors_on(changeset).port != []
    end

    test "enforces unique name per workspace", %{scope: scope} do
      attrs = valid_data_source_attributes(%{name: "same-name"})
      {:ok, _} = DataSources.create_data_source(scope, attrs)
      assert {:error, changeset} = DataSources.create_data_source(scope, attrs)
      assert "has already been taken" in errors_on(changeset).name
    end

    test "allows same name in different workspaces", %{scope: scope} do
      other_scope = user_scope_fixture()
      attrs = valid_data_source_attributes(%{name: "same-name"})

      assert {:ok, _} = DataSources.create_data_source(scope, attrs)
      assert {:ok, _} = DataSources.create_data_source(other_scope, attrs)
    end
  end

  describe "update_data_source_status/2" do
    test "updates status", %{scope: scope} do
      ds = data_source_fixture(scope)
      assert {:ok, updated} = DataSources.update_data_source_status(ds, "connected")
      assert updated.status == "connected"
    end

    test "rejects invalid status", %{scope: scope} do
      ds = data_source_fixture(scope)
      assert {:error, changeset} = DataSources.update_data_source_status(ds, "invalid")
      assert errors_on(changeset).status != []
    end
  end

  describe "change_data_source/2" do
    test "returns a changeset", %{scope: scope} do
      ds = data_source_fixture(scope)
      assert %Ecto.Changeset{} = DataSources.change_data_source(ds)
    end
  end
end
