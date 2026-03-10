defmodule Onesqlx.Querying do
  @moduledoc """
  The Querying context.

  Handles read-only SQL execution against external data sources. Provides
  controlled query execution with timeouts, row limits, and result formatting.
  """

  import Ecto.Query

  alias Onesqlx.Accounts.Scope
  alias Onesqlx.Querying.QueryRun
  alias Onesqlx.Repo

  @doc """
  Records a query run for audit purposes.
  """
  def record_query_run(%Scope{} = scope, attrs) do
    %QueryRun{workspace_id: scope.workspace.id}
    |> QueryRun.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists recent query runs for the current user and data source.

  Results are ordered by `executed_at` descending. Accepts an optional `:limit`
  option (default: 20).
  """
  def list_recent_runs(%Scope{} = scope, data_source_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    QueryRun
    |> where(workspace_id: ^scope.workspace.id, user_id: ^scope.user.id)
    |> where(data_source_id: ^data_source_id)
    |> order_by(desc: :executed_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Gets a single query run by ID, scoped to the workspace.

  Raises `Ecto.NoResultsError` if not found.
  """
  def get_query_run!(%Scope{} = scope, id) do
    QueryRun
    |> where(workspace_id: ^scope.workspace.id, id: ^id)
    |> Repo.one!()
  end
end
