defmodule Onesqlx.Scheduling do
  @moduledoc """
  The Scheduling context.

  Manages scheduled execution of queries via Oban background jobs. Supports
  cron-based schedules for recurring query execution and result delivery.
  """

  import Ecto.Query

  alias Onesqlx.Accounts.Scope
  alias Onesqlx.Repo
  alias Onesqlx.Scheduling.ScheduledQuery
  alias Onesqlx.Scheduling.ScheduledQueryRun

  @doc """
  Lists scheduled queries for the workspace, with optional filters.

  ## Options

    * `:enabled_only` — when `true`, returns only enabled schedules
    * `:saved_query_id` — filters by saved query UUID
  """
  def list_scheduled_queries(%Scope{} = scope, opts \\ []) do
    ScheduledQuery
    |> where(workspace_id: ^scope.workspace.id)
    |> maybe_filter_enabled(opts[:enabled_only])
    |> maybe_filter_saved_query(opts[:saved_query_id])
    |> order_by(:name)
    |> preload(:saved_query)
    |> Repo.all()
  end

  @doc """
  Gets a single scheduled query scoped to the workspace.

  Preloads saved_query with data_source.
  Raises `Ecto.NoResultsError` if not found.
  """
  def get_scheduled_query!(%Scope{} = scope, id) do
    ScheduledQuery
    |> where(workspace_id: ^scope.workspace.id, id: ^id)
    |> preload(saved_query: :data_source)
    |> Repo.one!()
  end

  @doc """
  Creates a scheduled query for the workspace in the given scope.

  Sets workspace_id and user_id from scope. Computes initial next_run_at.
  """
  def create_scheduled_query(%Scope{} = scope, attrs) do
    %ScheduledQuery{workspace_id: scope.workspace.id, user_id: scope.user.id}
    |> ScheduledQuery.changeset(attrs)
    |> maybe_set_next_run_at()
    |> Repo.insert()
  end

  @doc """
  Updates a scheduled query. Recomputes next_run_at if schedule changed.
  """
  def update_scheduled_query(%Scope{} = _scope, %ScheduledQuery{} = sq, attrs) do
    sq
    |> ScheduledQuery.changeset(attrs)
    |> maybe_set_next_run_at()
    |> Repo.update()
  end

  @doc """
  Deletes a scheduled query. Cascades to its runs.
  """
  def delete_scheduled_query(%Scope{} = _scope, %ScheduledQuery{} = sq) do
    Repo.delete(sq)
  end

  @doc """
  Toggles the enabled flag. Sets next_run_at when enabling, clears when disabling.
  """
  def toggle_enabled(%Scope{} = _scope, %ScheduledQuery{} = sq) do
    new_enabled = !sq.enabled

    attrs =
      if new_enabled do
        %{enabled: true, next_run_at: compute_next_run_at(sq.schedule_type, sq.cron_expression)}
      else
        %{enabled: false, next_run_at: nil}
      end

    sq
    |> ScheduledQuery.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns a changeset for tracking scheduled query changes.
  """
  def change_scheduled_query(%ScheduledQuery{} = sq, attrs \\ %{}) do
    ScheduledQuery.changeset(sq, attrs)
  end

  @doc """
  Lists runs for a scheduled query, ordered by started_at desc.

  ## Options

    * `:limit` — max results (default 20)
  """
  def list_runs(%Scope{} = _scope, scheduled_query_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    ScheduledQueryRun
    |> where(scheduled_query_id: ^scheduled_query_id)
    |> order_by(desc: :started_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Records a run for a scheduled query and updates parent timestamps.
  """
  def record_run(%ScheduledQuery{} = sq, attrs) do
    run_attrs = Map.put(attrs, :scheduled_query_id, sq.id)

    Repo.transaction(fn ->
      {:ok, run} =
        %ScheduledQueryRun{}
        |> ScheduledQueryRun.changeset(run_attrs)
        |> Repo.insert()

      next = compute_next_run_at(sq.schedule_type, sq.cron_expression)

      {1, _} =
        ScheduledQuery
        |> where(id: ^sq.id)
        |> Repo.update_all(
          set: [
            last_run_at: DateTime.utc_now(:second),
            next_run_at: next
          ]
        )

      run
    end)
  end

  @doc """
  Lists due scheduled queries (system-level, no scope).

  Returns enabled queries whose next_run_at is in the past.
  Preloads saved_query with data_source.
  """
  def list_due_queries do
    now = DateTime.utc_now(:second)

    ScheduledQuery
    |> where([sq], sq.enabled == true and not is_nil(sq.next_run_at) and sq.next_run_at <= ^now)
    |> preload(saved_query: :data_source)
    |> Repo.all()
  end

  defp maybe_filter_enabled(query, true), do: where(query, [sq], sq.enabled == true)
  defp maybe_filter_enabled(query, _), do: query

  defp maybe_filter_saved_query(query, nil), do: query

  defp maybe_filter_saved_query(query, sq_id),
    do: where(query, [sq], sq.saved_query_id == ^sq_id)

  defp maybe_set_next_run_at(changeset) do
    enabled = Ecto.Changeset.get_field(changeset, :enabled)
    schedule_type = Ecto.Changeset.get_field(changeset, :schedule_type)
    cron_expression = Ecto.Changeset.get_field(changeset, :cron_expression)

    if enabled do
      next = compute_next_run_at(schedule_type, cron_expression)
      Ecto.Changeset.put_change(changeset, :next_run_at, next)
    else
      Ecto.Changeset.put_change(changeset, :next_run_at, nil)
    end
  end

  @doc false
  def compute_next_run_at(schedule_type, _cron_expression \\ nil) do
    now = DateTime.utc_now(:second)

    case schedule_type do
      "hourly" ->
        now |> DateTime.add(3600, :second) |> DateTime.truncate(:second)

      "daily" ->
        now
        |> DateTime.add(86_400, :second)
        |> Map.merge(%{hour: 0, minute: 0, second: 0})
        |> DateTime.truncate(:second)

      "weekly" ->
        days_until_monday = rem(8 - Date.day_of_week(now), 7)
        days = if days_until_monday == 0, do: 7, else: days_until_monday

        now
        |> DateTime.add(days * 86_400, :second)
        |> Map.merge(%{hour: 0, minute: 0, second: 0})
        |> DateTime.truncate(:second)

      "cron" ->
        # Placeholder: will be replaced by CronParser in Task 9.4
        now |> DateTime.add(3600, :second) |> DateTime.truncate(:second)

      _ ->
        now |> DateTime.add(86_400, :second) |> DateTime.truncate(:second)
    end
  end
end
