defmodule OnesqlxWeb.SavedQueryLive.Index do
  @moduledoc """
  LiveView for browsing, searching, and managing saved SQL queries.
  """

  use OnesqlxWeb, :live_view

  alias Onesqlx.DataSources
  alias Onesqlx.SavedQueries

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Saved Queries
        <:subtitle>Browse and manage your saved SQL queries.</:subtitle>
        <:actions>
          <.link navigate={~p"/sql-editor"}>
            <.button variant="primary">New Query</.button>
          </.link>
        </:actions>
      </.header>

      <%!-- Filters --%>
      <form phx-change="filter" class="flex items-center gap-4 mb-6">
        <input
          type="text"
          name="search"
          value={@search}
          placeholder="Search by title..."
          phx-debounce="300"
          class="input input-bordered input-sm w-64"
        />
        <select name="data_source_id" class="select select-bordered select-sm">
          <option value="">All data sources</option>
          <option
            :for={ds <- @data_sources}
            value={ds.id}
            selected={ds.id == @filter_data_source_id}
          >
            {ds.name}
          </option>
        </select>
        <label class="flex items-center gap-2 cursor-pointer">
          <input
            type="checkbox"
            name="favorites"
            value="true"
            checked={@filter_favorites}
            class="checkbox checkbox-sm"
          />
          <span class="text-sm">Favorites only</span>
        </label>
      </form>

      <%!-- Queries list --%>
      <div id="saved-queries" phx-update="stream" class="space-y-3">
        <div
          :for={{dom_id, query} <- @streams.saved_queries}
          id={dom_id}
          class="card border border-base-300 p-4"
        >
          <div class="flex items-start justify-between">
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <h3 class="font-semibold truncate">{query.title}</h3>
                <button
                  phx-click="toggle_favorite"
                  phx-value-id={query.id}
                  class="btn btn-ghost btn-xs"
                  aria-label={
                    if query.is_favorite, do: "Remove from favorites", else: "Add to favorites"
                  }
                >
                  <.icon
                    name={if query.is_favorite, do: "hero-star-solid", else: "hero-star"}
                    class={["size-4", query.is_favorite && "text-warning"]}
                  />
                </button>
              </div>
              <p :if={query.description} class="text-sm text-base-content/60 truncate mt-1">
                {query.description}
              </p>
              <p class="text-xs font-mono text-base-content/40 truncate mt-1">
                {query.sql}
              </p>
              <div class="flex items-center gap-2 mt-2">
                <span :if={query.data_source} class="badge badge-sm badge-outline">
                  {query.data_source.name}
                </span>
                <span :for={tag <- query.tags} class="badge badge-sm badge-ghost">{tag}</span>
              </div>
            </div>
            <div class="flex items-center gap-2 ml-4 flex-shrink-0">
              <button
                phx-click="open_edit_modal"
                phx-value-id={query.id}
                class="btn btn-sm btn-ghost"
                aria-label="Edit query"
              >
                <.icon name="hero-pencil-square" class="size-4" />
              </button>
              <.link
                navigate={~p"/sql-editor?saved_query_id=#{query.id}"}
                class="btn btn-sm btn-primary"
              >
                Open in Editor
              </.link>
              <button
                phx-click="delete"
                phx-value-id={query.id}
                data-confirm="Are you sure you want to delete this saved query?"
                class="btn btn-sm btn-ghost text-error"
                aria-label="Delete query"
              >
                <.icon name="hero-trash" class="size-4" />
              </button>
            </div>
          </div>
        </div>
      </div>

      <div :if={!@has_saved_queries?} class="text-center py-12">
        <.icon name="hero-bookmark" class="size-12 text-base-content/20 mx-auto mb-4" />
        <p class="text-base-content/60 mb-2">No saved queries yet</p>
        <p class="text-sm text-base-content/40 mb-4">
          Write a SQL query in the editor and save it for reuse.
        </p>
        <.link navigate={~p"/sql-editor"} class="btn btn-primary btn-sm">
          Open SQL Editor
        </.link>
      </div>

      <div
        :if={@show_edit_modal?}
        role="dialog"
        aria-modal="true"
        class="fixed inset-0 z-50 flex items-center justify-center"
      >
        <div class="fixed inset-0 bg-black/50" phx-click="close_edit_modal"></div>
        <div class="relative bg-base-100 rounded-lg p-6 w-full max-w-lg shadow-xl">
          <h3 class="text-lg font-semibold mb-4">Edit Query</h3>
          <.form
            for={@edit_form}
            id="edit-query-form"
            phx-submit="update_query"
            phx-change="validate_edit"
          >
            <.input field={@edit_form[:title]} type="text" label="Title" required />
            <.input field={@edit_form[:description]} type="textarea" label="Description" />
            <.input field={@edit_form[:sql]} type="textarea" label="SQL" class="font-mono text-sm" />
            <div class="form-control mb-4">
              <label class="label"><span class="label-text">Tags (comma-separated)</span></label>
              <input
                type="text"
                name="saved_query[tags_input]"
                value={@edit_tags_input}
                placeholder="analytics, daily, revenue"
                class="input input-bordered w-full"
              />
            </div>
            <div class="flex justify-end gap-2 mt-4">
              <button type="button" phx-click="close_edit_modal" class="btn btn-sm">Cancel</button>
              <.button variant="primary" phx-disable-with="Saving...">Save</.button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    data_sources = DataSources.list_data_sources(scope)
    saved_queries = SavedQueries.list_saved_queries(scope)

    socket =
      socket
      |> assign(
        data_sources: data_sources,
        search: "",
        filter_data_source_id: nil,
        filter_favorites: false,
        has_saved_queries?: saved_queries != [],
        show_edit_modal?: false,
        edit_form: nil,
        editing_query: nil,
        edit_tags_input: ""
      )
      |> stream(:saved_queries, saved_queries)

    {:ok, socket}
  end

  @impl true
  def handle_event("filter", params, socket) do
    scope = socket.assigns.current_scope
    search = params["search"] || ""

    ds_id =
      case params["data_source_id"] do
        "" -> nil
        id -> id
      end

    favorites = params["favorites"] == "true"
    opts = [search: search, favorites_only: favorites, data_source_id: ds_id]
    saved_queries = SavedQueries.list_saved_queries(scope, opts)

    socket =
      socket
      |> assign(
        search: search,
        filter_data_source_id: ds_id,
        filter_favorites: favorites,
        has_saved_queries?: saved_queries != []
      )
      |> stream(:saved_queries, saved_queries, reset: true)

    {:noreply, socket}
  end

  def handle_event("toggle_favorite", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    saved_query = SavedQueries.get_saved_query!(scope, id)
    {:ok, updated} = SavedQueries.toggle_favorite(scope, saved_query)
    updated = Onesqlx.Repo.preload(updated, :data_source)
    {:noreply, stream_insert(socket, :saved_queries, updated)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    saved_query = SavedQueries.get_saved_query!(scope, id)
    {:ok, _} = SavedQueries.delete_saved_query(scope, saved_query)
    {:noreply, stream_delete(socket, :saved_queries, saved_query)}
  end

  def handle_event("open_edit_modal", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    query = SavedQueries.get_saved_query!(scope, id)
    changeset = SavedQueries.change_saved_query(query)

    {:noreply,
     assign(socket,
       show_edit_modal?: true,
       editing_query: query,
       edit_form: to_form(changeset, as: "saved_query"),
       edit_tags_input: Enum.join(query.tags || [], ", ")
     )}
  end

  def handle_event("close_edit_modal", _params, socket) do
    {:noreply, assign(socket, show_edit_modal?: false, edit_form: nil, editing_query: nil)}
  end

  def handle_event("validate_edit", %{"saved_query" => params}, socket) do
    changeset =
      socket.assigns.editing_query
      |> SavedQueries.change_saved_query(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, edit_form: to_form(changeset, as: "saved_query"))}
  end

  def handle_event("update_query", %{"saved_query" => params}, socket) do
    scope = socket.assigns.current_scope
    query = socket.assigns.editing_query

    # Convert comma-separated tags to array
    tags =
      (params["tags_input"] || "")
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    attrs = Map.put(params, "tags", tags) |> Map.delete("tags_input")

    case SavedQueries.update_saved_query(scope, query, attrs) do
      {:ok, updated} ->
        updated = Onesqlx.Repo.preload(updated, :data_source)

        {:noreply,
         socket
         |> stream_insert(:saved_queries, updated)
         |> assign(show_edit_modal?: false, edit_form: nil, editing_query: nil)
         |> put_flash(:info, "Query updated.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, edit_form: to_form(changeset, as: "saved_query"))}
    end
  end
end
