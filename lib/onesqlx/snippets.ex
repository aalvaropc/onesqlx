defmodule Onesqlx.Snippets do
  @moduledoc """
  Context for managing reusable SQL snippets.
  """

  import Ecto.Query

  alias Onesqlx.Accounts.Scope
  alias Onesqlx.Repo
  alias Onesqlx.Snippets.SqlSnippet

  def list_snippets(%Scope{} = scope) do
    SqlSnippet
    |> where(workspace_id: ^scope.workspace.id)
    |> order_by(:title)
    |> Repo.all()
  end

  def create_snippet(%Scope{} = scope, attrs) do
    %SqlSnippet{workspace_id: scope.workspace.id, user_id: scope.user.id}
    |> SqlSnippet.changeset(attrs)
    |> Repo.insert()
  end

  def delete_snippet(%Scope{} = scope, id) do
    SqlSnippet
    |> where(workspace_id: ^scope.workspace.id, id: ^id)
    |> Repo.one!()
    |> Repo.delete()
  end

  def change_snippet(%SqlSnippet{} = snippet, attrs \\ %{}) do
    SqlSnippet.changeset(snippet, attrs)
  end
end
