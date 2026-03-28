defmodule Onesqlx.Audit do
  @moduledoc """
  The Audit context.

  Tracks activity and system events. Records user actions, query executions,
  and other significant events for accountability and usage analysis.
  """

  import Ecto.Query

  alias Onesqlx.Accounts.Scope
  alias Onesqlx.Audit.AuditEvent
  alias Onesqlx.Querying.QueryRun
  alias Onesqlx.Repo

  @doc """
  Records an audit event for the workspace in the given scope.
  """
  def record_event(%Scope{} = scope, event_type, attrs \\ %{}) do
    %AuditEvent{
      workspace_id: scope.workspace.id,
      user_id: scope.user.id,
      occurred_at: DateTime.utc_now(:second)
    }
    |> AuditEvent.changeset(Map.put(attrs, :event_type, event_type))
    |> Repo.insert()
  end

  @doc """
  Lists audit events for the workspace, with optional filters.

  ## Options

    * `:event_type` — filter by event type string
    * `:resource_type` — filter by resource type string
    * `:since` — only events after this DateTime
    * `:limit` — max results (default 50)
    * `:offset` — skip N results (default 0)
  """
  def list_events(%Scope{} = scope, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)

    AuditEvent
    |> where(workspace_id: ^scope.workspace.id)
    |> maybe_filter_event_type(opts[:event_type])
    |> maybe_filter_resource_type(opts[:resource_type])
    |> maybe_filter_since(opts[:since])
    |> order_by(desc: :occurred_at)
    |> limit(^limit)
    |> offset(^offset)
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Counts audit events for the workspace, with the same filters as `list_events/2`.
  """
  def count_events(%Scope{} = scope, opts \\ []) do
    AuditEvent
    |> where(workspace_id: ^scope.workspace.id)
    |> maybe_filter_event_type(opts[:event_type])
    |> maybe_filter_resource_type(opts[:resource_type])
    |> maybe_filter_since(opts[:since])
    |> Repo.aggregate(:count)
  end

  @doc """
  Returns query execution statistics for the workspace.

  Queries `query_runs` directly for accurate execution metrics.

  ## Options

    * `:since` — only runs after this DateTime
  """
  def query_execution_stats(%Scope{} = scope, opts \\ []) do
    base_query =
      QueryRun
      |> where(workspace_id: ^scope.workspace.id)
      |> maybe_filter_run_since(opts[:since])

    total = Repo.aggregate(base_query, :count)

    successful =
      base_query
      |> where([r], r.status == "success")
      |> Repo.aggregate(:count)

    failed = total - successful

    avg_duration_ms =
      base_query
      |> where([r], not is_nil(r.duration_ms))
      |> Repo.aggregate(:avg, :duration_ms)

    %{
      total_executions: total,
      successful: successful,
      failed: failed,
      avg_duration_ms:
        if(avg_duration_ms,
          do: Decimal.round(avg_duration_ms, 0) |> Decimal.to_integer(),
          else: 0
        )
    }
  end

  @doc """
  Returns the most active users in the workspace by event count.

  ## Options

    * `:since` — only events after this DateTime
    * `:limit` — max results (default 10)
  """
  def most_active_users(%Scope{} = scope, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    AuditEvent
    |> where(workspace_id: ^scope.workspace.id)
    |> where([e], not is_nil(e.user_id))
    |> maybe_filter_since(opts[:since])
    |> join(:inner, [e], u in assoc(e, :user))
    |> group_by([e, u], u.email)
    |> select([e, u], {u.email, count(e.id)})
    |> order_by([e, u], desc: count(e.id))
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Returns the slowest query runs in the workspace.

  ## Options

    * `:since` — only runs after this DateTime
    * `:limit` — max results (default 10)
  """
  def slowest_queries(%Scope{} = scope, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    QueryRun
    |> where(workspace_id: ^scope.workspace.id)
    |> where([r], not is_nil(r.duration_ms))
    |> maybe_filter_run_since(opts[:since])
    |> order_by(desc: :duration_ms)
    |> limit(^limit)
    |> Repo.all()
  end

  defp maybe_filter_event_type(query, nil), do: query
  defp maybe_filter_event_type(query, type), do: where(query, [e], e.event_type == ^type)

  defp maybe_filter_resource_type(query, nil), do: query
  defp maybe_filter_resource_type(query, type), do: where(query, [e], e.resource_type == ^type)

  defp maybe_filter_since(query, nil), do: query
  defp maybe_filter_since(query, since), do: where(query, [e], e.occurred_at >= ^since)

  defp maybe_filter_run_since(query, nil), do: query
  defp maybe_filter_run_since(query, since), do: where(query, [r], r.inserted_at >= ^since)
end
