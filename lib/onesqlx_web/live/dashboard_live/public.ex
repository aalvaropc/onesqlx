defmodule OnesqlxWeb.DashboardLive.Public do
  @moduledoc """
  Read-only public view of a shared dashboard. No authentication required.
  """

  use OnesqlxWeb, :live_view

  import OnesqlxWeb.DashboardLive.CardHelpers

  alias Onesqlx.Dashboards

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 py-6">
      <div class="flex items-center gap-4 mb-6">
        <h1 class="text-2xl font-bold flex-1">{@dashboard.title}</h1>
        <p :if={@dashboard.description} class="text-sm text-base-content/60">
          {@dashboard.description}
        </p>
      </div>

      <div :if={@applied_params != %{}} class="flex items-center gap-2 mb-3">
        <span class="text-xs text-base-content/60">Filters:</span>
        <span
          :for={{name, value} <- @applied_params}
          class="badge badge-sm badge-primary gap-1"
        >
          {name} = {value}
        </span>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div
          :for={card <- @dashboard.cards}
          id={"card-#{card.id}"}
          class={["card border border-base-300 p-4", card_span_class(card)]}
        >
          <h3 class="font-semibold mb-3">
            {card.title || (card.saved_query && card.saved_query.title) || "Untitled Card"}
          </h3>
          <.card_content card={card} result={Map.get(@card_results, card.id, :loading)} />
        </div>
      </div>

      <div :if={@dashboard.cards == []} class="text-center py-12">
        <p class="text-base-content/60">This dashboard has no cards yet.</p>
      </div>

      <p class="text-center text-xs text-base-content/30 mt-8">
        Powered by OneSQLx
      </p>
    </div>
    """
  end

  @impl true
  def mount(%{"token" => token} = params, _session, socket) do
    dashboard = Dashboards.get_public_dashboard!(token)
    query_params = public_query_params(dashboard, params)

    if connected?(socket), do: Dashboards.subscribe(dashboard.id)

    card_results =
      Map.new(dashboard.cards, fn card ->
        {card.id, initial_card_result(card)}
      end)

    socket =
      socket
      |> assign(dashboard: dashboard, card_results: card_results, applied_params: query_params)
      |> start_card_async_tasks(dashboard.cards, query_params)

    {:ok, socket, layout: false}
  end

  @impl true
  def handle_info({:dashboard_updated, _id}, socket) do
    dashboard = Dashboards.get_public_dashboard!(socket.assigns.dashboard.public_token)
    query_params = public_query_params(dashboard, socket.assigns.applied_params)

    card_results =
      Map.new(dashboard.cards, fn card ->
        {card.id, initial_card_result(card)}
      end)

    socket =
      socket
      |> assign(dashboard: dashboard, card_results: card_results, applied_params: query_params)
      |> start_card_async_tasks(dashboard.cards, query_params)

    {:noreply, socket}
  end

  @impl true
  def handle_async({:execute_card, id}, {:ok, {:ok, result}}, socket) do
    {:noreply, update(socket, :card_results, &Map.put(&1, id, {:ok, result}))}
  end

  def handle_async({:execute_card, id}, {:ok, {:error, _type, msg}}, socket) do
    {:noreply, update(socket, :card_results, &Map.put(&1, id, {:error, msg}))}
  end

  def handle_async({:execute_card, id}, {:exit, reason}, socket) do
    {:noreply,
     update(socket, :card_results, &Map.put(&1, id, {:error, "Query failed: #{inspect(reason)}"}))}
  end
end
