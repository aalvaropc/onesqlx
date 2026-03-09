defmodule Onesqlx.WorkspacesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Onesqlx.Workspaces` context.
  """

  alias Onesqlx.Workspaces

  def workspace_fixture(user, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{name: "Test Workspace"})

    {:ok, workspace} = Workspaces.create_workspace_with_owner(user, attrs)
    workspace
  end

  def add_member_fixture(workspace, user, role \\ "member") do
    {:ok, member} = Workspaces.add_member(workspace, user, role)
    member
  end
end
