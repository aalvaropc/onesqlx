defmodule Onesqlx.SavedQueries do
  @moduledoc """
  The SavedQueries context.

  Manages persistence and organization of SQL queries. Users can save,
  name, describe, and organize queries within their workspace.
  """

  import Ecto.Query

  alias Onesqlx.Accounts.Scope
  alias Onesqlx.Audit
  alias Onesqlx.Repo
  alias Onesqlx.SavedQueries.SavedQuery

  @doc """
  Lists saved queries for the workspace, with optional filters.

  ## Options

    * `:search` — case-insensitive title search (ILIKE)
    * `:favorites_only` — when `true`, returns only favorited queries
    * `:data_source_id` — filters by data source UUID
    * `:tag` — filters queries containing the given tag
  """
  def list_saved_queries(%Scope{} = scope, opts \\ []) do
    SavedQuery
    |> where(workspace_id: ^scope.workspace.id)
    |> maybe_filter_search(opts[:search])
    |> maybe_filter_favorites(opts[:favorites_only])
    |> maybe_filter_data_source(opts[:data_source_id])
    |> maybe_filter_tag(opts[:tag])
    |> maybe_filter_collection(opts[:collection])
    |> order_by(desc: :updated_at)
    |> preload(:data_source)
    |> Repo.all()
  end

  @doc """
  Gets a single saved query by ID, scoped to the workspace.

  Raises `Ecto.NoResultsError` if not found.
  """
  def get_saved_query!(%Scope{} = scope, id) do
    SavedQuery
    |> where(workspace_id: ^scope.workspace.id, id: ^id)
    |> preload(:data_source)
    |> Repo.one!()
  end

  @doc """
  Creates a saved query for the workspace in the given scope.
  """
  def create_saved_query(%Scope{} = scope, attrs) do
    result =
      %SavedQuery{workspace_id: scope.workspace.id}
      |> SavedQuery.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, sq} ->
        Task.start(fn ->
          Audit.record_event(scope, "query.saved", %{
            resource_type: "saved_query",
            resource_id: sq.id
          })
        end)

      _ ->
        :ok
    end

    result
  end

  @doc """
  Updates a saved query.
  """
  def update_saved_query(%Scope{} = _scope, %SavedQuery{} = saved_query, attrs) do
    saved_query
    |> SavedQuery.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a saved query.
  """
  def delete_saved_query(%Scope{} = scope, %SavedQuery{} = saved_query) do
    result = Repo.delete(saved_query)

    case result do
      {:ok, sq} ->
        Task.start(fn ->
          Audit.record_event(scope, "query.deleted", %{
            resource_type: "saved_query",
            resource_id: sq.id
          })
        end)

      _ ->
        :ok
    end

    result
  end

  @doc """
  Toggles the `is_favorite` field on a saved query.
  """
  def toggle_favorite(%Scope{} = _scope, %SavedQuery{} = saved_query) do
    saved_query
    |> SavedQuery.changeset(%{is_favorite: !saved_query.is_favorite})
    |> Repo.update()
  end

  @doc """
  Returns a changeset for tracking saved query changes.
  """
  def change_saved_query(%SavedQuery{} = saved_query, attrs \\ %{}) do
    SavedQuery.changeset(saved_query, attrs)
  end

  defp maybe_filter_search(query, nil), do: query
  defp maybe_filter_search(query, ""), do: query

  defp maybe_filter_search(query, search) do
    search_term = "%#{search}%"
    where(query, [q], ilike(q.title, ^search_term))
  end

  defp maybe_filter_favorites(query, true), do: where(query, [q], q.is_favorite == true)
  defp maybe_filter_favorites(query, _), do: query

  defp maybe_filter_data_source(query, nil), do: query
  defp maybe_filter_data_source(query, ds_id), do: where(query, [q], q.data_source_id == ^ds_id)

  defp maybe_filter_tag(query, nil), do: query
  defp maybe_filter_tag(query, tag), do: where(query, [q], ^tag in q.tags)

  defp maybe_filter_collection(query, nil), do: query

  defp maybe_filter_collection(query, collection),
    do: where(query, [q], q.collection == ^collection)

  @doc """
  Lists distinct collection names for the workspace.
  """
  def list_collections(%Scope{} = scope) do
    SavedQuery
    |> where(workspace_id: ^scope.workspace.id)
    |> where([q], not is_nil(q.collection))
    |> select([q], q.collection)
    |> distinct(true)
    |> order_by(:collection)
    |> Repo.all()
  end
end
