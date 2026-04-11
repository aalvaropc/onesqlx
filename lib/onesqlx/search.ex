defmodule Onesqlx.Search do
  @moduledoc """
  Global search across all workspace entities.
  """

  import Ecto.Query

  alias Onesqlx.Accounts.Scope
  alias Onesqlx.Dashboards.Dashboard
  alias Onesqlx.DataSources.DataSource
  alias Onesqlx.Repo
  alias Onesqlx.SavedQueries.SavedQuery
  alias Onesqlx.Scheduling.ScheduledQuery

  @max_results_per_type 5

  @doc """
  Searches across saved queries, dashboards, schedules, and data sources.

  Returns a map with results grouped by type, limited to #{@max_results_per_type} per type.
  """
  def search(%Scope{} = scope, query) when is_binary(query) and query != "" do
    term = "%#{query}%"
    ws_id = scope.workspace.id

    %{
      saved_queries: search_saved_queries(ws_id, term),
      dashboards: search_dashboards(ws_id, term),
      schedules: search_schedules(ws_id, term),
      data_sources: search_data_sources(ws_id, term)
    }
  end

  def search(_scope, _query),
    do: %{saved_queries: [], dashboards: [], schedules: [], data_sources: []}

  defp search_saved_queries(ws_id, term) do
    SavedQuery
    |> where(workspace_id: ^ws_id)
    |> where([q], ilike(q.title, ^term))
    |> order_by(desc: :updated_at)
    |> limit(@max_results_per_type)
    |> select([q], %{id: q.id, title: q.title})
    |> Repo.all()
  end

  defp search_dashboards(ws_id, term) do
    Dashboard
    |> where(workspace_id: ^ws_id)
    |> where([d], ilike(d.title, ^term))
    |> order_by(desc: :updated_at)
    |> limit(@max_results_per_type)
    |> select([d], %{id: d.id, title: d.title})
    |> Repo.all()
  end

  defp search_schedules(ws_id, term) do
    ScheduledQuery
    |> where(workspace_id: ^ws_id)
    |> where([s], ilike(s.name, ^term))
    |> order_by(:name)
    |> limit(@max_results_per_type)
    |> select([s], %{id: s.id, name: s.name})
    |> Repo.all()
  end

  defp search_data_sources(ws_id, term) do
    DataSource
    |> where(workspace_id: ^ws_id)
    |> where([ds], ilike(ds.name, ^term))
    |> order_by(:name)
    |> limit(@max_results_per_type)
    |> select([ds], %{id: ds.id, name: ds.name})
    |> Repo.all()
  end
end
