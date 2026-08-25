defmodule OnesqlxWeb.SearchLive do
  @moduledoc """
  LiveView for global search across all workspace entities.
  """

  use OnesqlxWeb, :live_view

  alias Onesqlx.Search

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Search
        <:subtitle>Find queries, dashboards, schedules, and data sources.</:subtitle>
      </.header>

      <form phx-change="search" class="mt-6 max-w-lg">
        <input
          type="text"
          name="q"
          value={@query}
          placeholder="Type to search..."
          phx-debounce="300"
          autofocus
          class="input input-bordered w-full"
        />
      </form>

      <div :if={@query != "" && @results} class="mt-6 space-y-6">
        <.result_group
          :if={@results.saved_queries != []}
          title="Saved Queries"
          icon="hero-bookmark"
          items={@results.saved_queries}
          link_fn={fn item -> ~p"/sql-editor?saved_query_id=#{item.id}" end}
          label_fn={fn item -> item.title end}
        />
        <.result_group
          :if={@results.dashboards != []}
          title="Dashboards"
          icon="hero-chart-bar-square"
          items={@results.dashboards}
          link_fn={fn item -> ~p"/dashboards/#{item.id}" end}
          label_fn={fn item -> item.title end}
        />
        <.result_group
          :if={@results.schedules != []}
          title="Schedules"
          icon="hero-clock"
          items={@results.schedules}
          link_fn={fn item -> ~p"/schedules/#{item.id}" end}
          label_fn={fn item -> item.name end}
        />
        <.result_group
          :if={@results.data_sources != []}
          title="Data Sources"
          icon="hero-circle-stack"
          items={@results.data_sources}
          link_fn={fn item -> ~p"/data-sources/#{item.id}/catalog" end}
          label_fn={fn item -> item.name end}
        />

        <div
          :if={
            @results.saved_queries == [] && @results.dashboards == [] && @results.schedules == [] &&
              @results.data_sources == []
          }
          class="text-center py-8"
        >
          <p class="text-base-content/60">No results found for "{@query}"</p>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :title, :string, required: true
  attr :icon, :string, required: true
  attr :items, :list, required: true
  attr :link_fn, :any, required: true
  attr :label_fn, :any, required: true

  defp result_group(assigns) do
    ~H"""
    <div>
      <h3 class="text-sm font-semibold text-base-content/60 mb-2 flex items-center gap-2">
        <.icon name={@icon} class="size-4" />
        {@title}
      </h3>
      <div class="space-y-1">
        <.link
          :for={item <- @items}
          navigate={@link_fn.(item)}
          class="flex flex-col gap-0.5 p-2 rounded hover:bg-base-200 transition-colors"
        >
          <span class="text-sm">{@label_fn.(item)}</span>
          <span :if={item[:snippet]} class="font-mono text-xs text-base-content/50 truncate">
            {item[:snippet]}
          </span>
        </.link>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, query: "", results: nil)}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    query = String.trim(query)

    results =
      if query == "" do
        nil
      else
        Search.search(socket.assigns.current_scope, query)
      end

    {:noreply, assign(socket, query: query, results: results)}
  end
end
