defmodule OnesqlxWeb.DashboardLive.Public do
  @moduledoc """
  Read-only public view of a shared dashboard. No authentication required.
  """

  use OnesqlxWeb, :live_view

  alias Onesqlx.Dashboards
  alias Onesqlx.Dashboards.CardRenderer
  alias Onesqlx.Querying.Executor

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

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div
          :for={card <- @dashboard.cards}
          id={"card-#{card.id}"}
          class="card border border-base-300 p-4"
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

  attr :card, :map, required: true
  attr :result, :any, required: true

  defp card_content(%{result: :loading} = assigns) do
    ~H"""
    <div class="flex items-center justify-center py-8">
      <span class="loading loading-spinner loading-md"></span>
    </div>
    """
  end

  defp card_content(%{result: {:error, _msg}} = assigns) do
    ~H"""
    <div class="alert alert-error text-sm">{elem(@result, 1)}</div>
    """
  end

  defp card_content(%{card: %{type: "kpi"}, result: {:ok, result}} = assigns) do
    kpi = CardRenderer.kpi_value_for(result)
    assigns = assign(assigns, :kpi, kpi)

    ~H"""
    <div :if={@kpi} class="text-center py-4">
      <p class="text-4xl font-bold">{elem(@kpi, 0)}</p>
      <p class="text-sm text-base-content/60 mt-1">{elem(@kpi, 1)}</p>
    </div>
    <div :if={!@kpi} class="text-center py-4 text-base-content/50 text-sm">No data</div>
    """
  end

  defp card_content(%{card: %{type: type}, result: {:ok, result}} = assigns)
       when type in ["bar", "line", "pie", "doughnut", "area", "scatter"] do
    chart_data = CardRenderer.chart_data_for(result)
    assigns = assign(assigns, chart_data: Jason.encode!(chart_data), chart_type: type)

    ~H"""
    <div
      id={"chart-#{@card.id}"}
      phx-hook="ChartCard"
      data-chart-type={@chart_type}
      data-chart-data={@chart_data}
      class="h-48"
    >
      <canvas></canvas>
    </div>
    """
  end

  defp card_content(%{result: {:ok, result}} = assigns) do
    rows = Enum.take(result.rows, 20)
    assigns = assign(assigns, columns: result.columns, rows: rows, total: result.row_count)

    ~H"""
    <div class="overflow-x-auto">
      <table class="table table-xs">
        <thead>
          <tr>
            <th :for={col <- @columns}>{col}</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={row <- @rows}>
            <td :for={cell <- row} class="font-mono text-xs">{format_cell(cell)}</td>
          </tr>
        </tbody>
      </table>
      <p :if={length(@rows) < @total} class="text-xs text-base-content/50 mt-1">
        Showing {length(@rows)} of {@total} rows
      </p>
    </div>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    dashboard = Dashboards.get_public_dashboard!(token)

    card_results =
      Map.new(dashboard.cards, fn card ->
        {card.id, initial_card_result(card)}
      end)

    socket =
      socket
      |> assign(dashboard: dashboard, card_results: card_results)
      |> start_card_async_tasks(dashboard.cards)

    {:ok, socket, layout: false}
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

  defp initial_card_result(%{saved_query: %{data_source: %{}} = _sq}), do: :loading
  defp initial_card_result(_card), do: {:error, "No query assigned"}

  defp start_card_async_tasks(socket, cards) do
    Enum.reduce(cards, socket, &maybe_start_card_async(&2, &1))
  end

  defp maybe_start_card_async(socket, card) do
    case card do
      %{saved_query: %{data_source: data_source, sql: sql}} when not is_nil(data_source) ->
        params = get_in(card.config, ["params"]) || %{}

        start_async(socket, {:execute_card, card.id}, fn ->
          Executor.execute(data_source, sql, params: params)
        end)

      _ ->
        socket
    end
  end

  defp format_cell(nil), do: "NULL"
  defp format_cell(true), do: "true"
  defp format_cell(false), do: "false"
  defp format_cell(%Decimal{} = value), do: Decimal.to_string(value)
  defp format_cell(%Date{} = value), do: Date.to_string(value)
  defp format_cell(%DateTime{} = value), do: DateTime.to_string(value)
  defp format_cell(%NaiveDateTime{} = value), do: NaiveDateTime.to_string(value)
  defp format_cell(%Time{} = value), do: Time.to_string(value)

  defp format_cell(value) when is_binary(value) do
    if String.length(value) > 500, do: String.slice(value, 0, 500) <> "...", else: value
  end

  defp format_cell(value) when is_number(value), do: to_string(value)
  defp format_cell(value), do: inspect(value)
end
