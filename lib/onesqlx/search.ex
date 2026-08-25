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
    term = "%#{escape_like(query)}%"
    ws_id = scope.workspace.id

    %{
      saved_queries: search_saved_queries(ws_id, term, query),
      dashboards: search_dashboards(ws_id, term),
      schedules: search_schedules(ws_id, term),
      data_sources: search_data_sources(ws_id, term)
    }
  end

  def search(_scope, _query),
    do: %{saved_queries: [], dashboards: [], schedules: [], data_sources: []}

  defp search_saved_queries(ws_id, term, query) do
    SavedQuery
    |> where(workspace_id: ^ws_id)
    |> where(
      [q],
      ilike(q.title, ^term) or ilike(q.description, ^term) or ilike(q.sql, ^term)
    )
    |> order_by(desc: :updated_at)
    |> limit(@max_results_per_type)
    |> select([q], %{id: q.id, title: q.title, description: q.description, sql: q.sql})
    |> Repo.all()
    |> Enum.map(fn result ->
      %{id: result.id, title: result.title, snippet: snippet(result, query)}
    end)
  end

  # A one-line context excerpt when the match came from the SQL body or
  # the description rather than the title.
  defp snippet(result, query) do
    downcased = String.downcase(query)

    cond do
      String.contains?(String.downcase(result.title), downcased) -> nil
      match = matching_line(result.description, downcased) -> match
      match = matching_line(result.sql, downcased) -> match
      true -> nil
    end
  end

  defp matching_line(nil, _downcased_query), do: nil

  defp matching_line(text, downcased_query) do
    text
    |> String.split("\n")
    |> Enum.find(&String.contains?(String.downcase(&1), downcased_query))
    |> case do
      nil -> nil
      line -> line |> String.trim() |> truncate(80)
    end
  end

  defp truncate(line, max) do
    if String.length(line) > max, do: String.slice(line, 0, max) <> "…", else: line
  end

  # ILIKE treats % _ \ specially; escape them so searching for "%" does
  # not match every row.
  defp escape_like(query) do
    String.replace(query, ~r/[\\%_]/, fn char -> "\\" <> char end)
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
