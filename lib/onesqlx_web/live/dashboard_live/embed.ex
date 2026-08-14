defmodule OnesqlxWeb.DashboardLive.Embed do
  @moduledoc """
  Embeddable dashboard view designed for iframe embedding.

  Renders a minimal, chrome-free dashboard without navigation or footer.
  Supports query parameters for passing dashboard-level parameters via the iframe URL.
  """

  use OnesqlxWeb, :live_view

  import OnesqlxWeb.DashboardLive.CardHelpers

  alias Onesqlx.Dashboards

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full px-4 py-3">
      <h1 class="text-lg font-semibold mb-3">{@dashboard.title}</h1>

      <div class="grid grid-cols-1 md:grid-cols-4 gap-3">
        <div
          :for={card <- @dashboard.cards}
          id={"card-#{card.id}"}
          class={["card border border-base-300 p-3", card_span_class(card)]}
        >
          <h3 class="font-medium text-sm mb-2">
            {card.title || (card.saved_query && card.saved_query.title) || "Untitled Card"}
          </h3>
          <.card_content card={card} result={Map.get(@card_results, card.id, :loading)} />
        </div>
      </div>

      <div :if={@dashboard.cards == []} class="text-center py-8">
        <p class="text-base-content/60 text-sm">This dashboard has no cards yet.</p>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"token" => token} = params, _session, socket) do
    dashboard = Dashboards.get_public_dashboard!(token)
    url_params = public_query_params(dashboard, params)

    if connected?(socket), do: Dashboards.subscribe(dashboard.id)

    card_results =
      Map.new(dashboard.cards, fn card ->
        {card.id, initial_card_result(card)}
      end)

    socket =
      socket
      |> assign(dashboard: dashboard, card_results: card_results, query_params: url_params)
      |> start_card_async_tasks(dashboard.cards, url_params)

    {:ok, socket, layout: false}
  end

  @impl true
  def handle_info({:dashboard_updated, _id}, socket) do
    dashboard = Dashboards.get_public_dashboard!(socket.assigns.dashboard.public_token)
    query_params = public_query_params(dashboard, socket.assigns.query_params)

    card_results =
      Map.new(dashboard.cards, fn card ->
        {card.id, initial_card_result(card)}
      end)

    socket =
      socket
      |> assign(dashboard: dashboard, card_results: card_results, query_params: query_params)
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
