defmodule Onesqlx.WorkspacesTest do
  use Onesqlx.DataCase

  alias Onesqlx.Workspaces
  alias Onesqlx.Workspaces.Workspace

  import Onesqlx.AccountsFixtures

  describe "create_workspace/1" do
    test "creates workspace with valid attrs" do
      assert {:ok, %Workspace{} = workspace} =
               Workspaces.create_workspace(%{name: "My Team", slug: "my-team"})

      assert workspace.name == "My Team"
      assert workspace.slug == "my-team"
    end

    test "auto-generates slug from name" do
      assert {:ok, %Workspace{} = workspace} =
               Workspaces.create_workspace(%{name: "My Cool Team"})

      assert workspace.slug == "my-cool-team"
    end

    test "validates name length" do
      assert {:error, changeset} = Workspaces.create_workspace(%{name: "X"})
      assert "should be at least 2 character(s)" in errors_on(changeset).name
    end

    test "validates slug format" do
      assert {:error, changeset} =
               Workspaces.create_workspace(%{name: "Valid", slug: "INVALID SLUG!"})

      assert errors_on(changeset).slug != []
    end

    test "rejects duplicate slugs" do
      assert {:ok, _} = Workspaces.create_workspace(%{name: "Team", slug: "unique-slug"})

      assert {:error, changeset} =
               Workspaces.create_workspace(%{name: "Other", slug: "unique-slug"})

      assert "has already been taken" in errors_on(changeset).slug
    end

    test "requires name" do
      assert {:error, changeset} = Workspaces.create_workspace(%{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "get_workspace!/1" do
    test "returns workspace by id" do
      {:ok, workspace} = Workspaces.create_workspace(%{name: "Test"})
      assert Workspaces.get_workspace!(workspace.id).id == workspace.id
    end
  end

  describe "change_workspace/2" do
    test "returns a changeset" do
      {:ok, workspace} = Workspaces.create_workspace(%{name: "Test"})
      assert %Ecto.Changeset{} = Workspaces.change_workspace(workspace)
    end
  end

  describe "create_workspace_with_owner/2" do
    test "creates workspace and assigns user as owner" do
      user = user_fixture()
      assert {:ok, workspace} = Workspaces.create_workspace_with_owner(user, %{name: "My Team"})

      assert workspace.name == "My Team"
      assert String.starts_with?(workspace.slug, "my-team-")
      assert Workspaces.get_member_role(workspace, user) == "owner"
    end
  end

  describe "add_member/3" do
    test "adds member with valid role" do
      owner = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace_with_owner(owner, %{name: "Team"})

      member = user_fixture()
      assert {:ok, wm} = Workspaces.add_member(workspace, member)
      assert wm.role == "member"
    end

    test "rejects invalid roles" do
      owner = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace_with_owner(owner, %{name: "Team"})

      member = user_fixture()
      assert {:error, changeset} = Workspaces.add_member(workspace, member, "superadmin")
      assert errors_on(changeset).role != []
    end

    test "rejects duplicate membership" do
      owner = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace_with_owner(owner, %{name: "Team"})

      member = user_fixture()
      assert {:ok, _} = Workspaces.add_member(workspace, member)
      assert {:error, changeset} = Workspaces.add_member(workspace, member)
      assert "has already been taken" in errors_on(changeset).workspace_id
    end
  end

  describe "list_members/1" do
    test "lists members of workspace" do
      owner = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace_with_owner(owner, %{name: "Team"})

      member = user_fixture()
      Workspaces.add_member(workspace, member)

      members = Workspaces.list_members(workspace)
      assert length(members) == 2
      assert Enum.any?(members, &(&1.user_id == owner.id))
      assert Enum.any?(members, &(&1.user_id == member.id))
    end
  end

  describe "get_member_role/2" do
    test "returns nil for non-member" do
      owner = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace_with_owner(owner, %{name: "Team"})

      non_member = user_fixture()
      assert Workspaces.get_member_role(workspace, non_member) == nil
    end
  end

  describe "member?/2" do
    test "returns true for member, false for non-member" do
      owner = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace_with_owner(owner, %{name: "Team"})

      assert Workspaces.member?(workspace, owner)

      non_member = user_fixture()
      refute Workspaces.member?(workspace, non_member)
    end
  end

  describe "list_workspaces_for_user/1" do
    test "returns only workspaces user belongs to" do
      user_a = user_fixture()
      user_b = user_fixture()

      workspaces_a = Workspaces.list_workspaces_for_user(user_a)
      workspaces_b = Workspaces.list_workspaces_for_user(user_b)

      workspace_ids_a = Enum.map(workspaces_a, & &1.id) |> MapSet.new()
      workspace_ids_b = Enum.map(workspaces_b, & &1.id) |> MapSet.new()

      # Each user has their own workspace(s), no overlap
      assert MapSet.disjoint?(workspace_ids_a, workspace_ids_b)
    end
  end

  describe "workspace isolation" do
    test "user A cannot see user B's workspace via list_workspaces_for_user" do
      user_a = user_fixture()
      user_b = user_fixture()

      [ws_a] = Workspaces.list_workspaces_for_user(user_a)
      [ws_b] = Workspaces.list_workspaces_for_user(user_b)

      refute ws_a.id == ws_b.id
    end

    test "get_workspace_for_scope returns only accessible workspaces" do
      user_a = user_fixture()
      user_b = user_fixture()

      [ws_b] = Workspaces.list_workspaces_for_user(user_b)

      # user_a cannot access user_b's workspace; falls back to own
      resolved = Workspaces.get_workspace_for_scope(user_a, ws_b.id)
      refute resolved.id == ws_b.id
    end
  end
end
