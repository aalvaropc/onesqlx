defmodule Onesqlx.Lineage do
  @moduledoc """
  Data lineage analysis for dashboards and queries.

  Extracts table references from SQL and builds dependency trees
  showing which dashboards depend on which queries and tables.
  """

  import Ecto.Query

  alias Onesqlx.Accounts.Scope
  alias Onesqlx.Dashboards
  alias Onesqlx.Repo
  alias Onesqlx.SavedQueries.SavedQuery

  @sql_keywords ~w(LATERAL UNNEST GENERATE_SERIES VALUES)

  @doc """
  Extracts table references from a SQL string.

  Returns a list of `{schema, table}` tuples. When no schema is specified,
  `"public"` is used as default. CTE names, subquery aliases, string literals,
  and comments are excluded.
  """
  @spec extract_tables(String.t()) :: [{String.t(), String.t()}]
  def extract_tables(sql) when is_binary(sql) do
    cte_names = extract_cte_names(sql)

    sql
    |> strip_string_literals()
    |> strip_comments()
    |> extract_table_refs()
    |> Enum.reject(fn {_schema, table} ->
      String.upcase(table) in @sql_keywords or table in cte_names
    end)
    |> Enum.uniq()
  end

  def extract_tables(_), do: []

  @doc """
  Builds a lineage tree for a dashboard.

  Returns a map with the dashboard info and its cards, each annotated
  with the tables their saved query references.
  """
  def build_dashboard_lineage(%Scope{} = scope, dashboard_id) do
    dashboard = Dashboards.get_dashboard_with_cards!(scope, dashboard_id)
    cards = Enum.map(dashboard.cards, &card_lineage/1)

    %{
      dashboard: %{id: dashboard.id, title: dashboard.title},
      cards: cards
    }
  end

  @doc """
  Finds all saved queries and dashboards that reference a given table.

  Returns `%{queries: [...], dashboards: [...]}`.
  """
  def build_table_lineage(%Scope{} = scope, table_name) do
    queries =
      SavedQuery
      |> where(workspace_id: ^scope.workspace.id)
      |> select([q], %{id: q.id, title: q.title, sql: q.sql})
      |> Repo.all()
      |> Enum.filter(fn q ->
        extract_tables(q.sql)
        |> Enum.any?(fn {_schema, name} ->
          String.downcase(name) == String.downcase(table_name)
        end)
      end)

    query_ids = Enum.map(queries, & &1.id)

    dashboards =
      if query_ids != [] do
        from(d in Onesqlx.Dashboards.Dashboard,
          join: c in assoc(d, :cards),
          where: c.saved_query_id in ^query_ids and d.workspace_id == ^scope.workspace.id,
          distinct: true,
          select: %{id: d.id, title: d.title}
        )
        |> Repo.all()
      else
        []
      end

    %{
      queries: Enum.map(queries, &%{id: &1.id, title: &1.title}),
      dashboards: dashboards
    }
  end

  # -- Private -----------------------------------------------------------------

  defp card_lineage(card) do
    tables = tables_from_query(card.saved_query)

    %{
      id: card.id,
      title: card.title || (card.saved_query && card.saved_query.title) || "Untitled",
      saved_query: card.saved_query && %{id: card.saved_query.id, title: card.saved_query.title},
      tables: tables
    }
  end

  defp tables_from_query(%{sql: sql}) when is_binary(sql) do
    Enum.map(extract_tables(sql), fn {schema, table} -> %{schema: schema, name: table} end)
  end

  defp tables_from_query(_), do: []

  defp strip_string_literals(sql) do
    Regex.replace(~r/'(?:[^']|'')*'/s, sql, "'__LIT__'")
  end

  defp strip_comments(sql) do
    sql = Regex.replace(~r{/\*.*?\*/}s, sql, " ")
    Regex.replace(~r{--[^\n]*}, sql, " ")
  end

  defp extract_cte_names(sql) do
    cleaned = sql |> strip_string_literals() |> strip_comments()

    Regex.scan(~r/\bWITH\b\s+(.+)/is, cleaned)
    |> Enum.flat_map(fn [_, body] -> parse_cte_names(body) end)
  end

  defp parse_cte_names(body) do
    Regex.scan(~r/(\w+)\s+AS\s*\(/i, body)
    |> Enum.map(fn [_, name] -> name end)
  end

  defp extract_table_refs(sql) do
    pattern = ~r/(?:FROM|JOIN)\s+(?:(\w+)\.)?(\w+)/i

    Regex.scan(pattern, sql)
    |> Enum.map(fn
      [_, "", table] -> {"public", table}
      [_, schema, table] -> {schema, table}
    end)
  end
end
