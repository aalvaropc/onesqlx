defmodule OnesqlxWeb.Api.SavedQueryController do
  @moduledoc """
  API controller for saved queries.
  """

  use OnesqlxWeb, :controller

  alias Onesqlx.DataSources
  alias Onesqlx.Querying.Executor
  alias Onesqlx.SavedQueries

  def index(conn, _params) do
    scope = conn.assigns.current_scope
    queries = SavedQueries.list_saved_queries(scope)
    json(conn, %{data: Enum.map(queries, &serialize_query/1)})
  end

  def show(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope
    query = SavedQueries.get_saved_query!(scope, id)
    json(conn, %{data: serialize_query(query)})
  end

  def execute(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope
    query = SavedQueries.get_saved_query!(scope, id)

    case query.data_source_id do
      nil ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "No data source assigned"})

      ds_id ->
        data_source = DataSources.get_data_source!(scope, ds_id)

        case Executor.execute(data_source, query.sql) do
          {:ok, result} ->
            json(conn, %{
              data: %{
                columns: result.columns,
                rows: result.rows,
                row_count: result.row_count,
                duration_ms: result.duration_ms
              }
            })

          {:error, _type, message} ->
            conn |> put_status(:unprocessable_entity) |> json(%{error: message})
        end
    end
  end

  defp serialize_query(q) do
    %{
      id: q.id,
      title: q.title,
      description: q.description,
      sql: q.sql,
      tags: q.tags,
      is_favorite: q.is_favorite,
      data_source_id: q.data_source_id,
      inserted_at: q.inserted_at,
      updated_at: q.updated_at
    }
  end
end
