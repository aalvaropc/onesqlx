defmodule OnesqlxWeb.DashboardLive.CardHelpers do
  @moduledoc """
  Shared card rendering and async execution helpers for the dashboard
  views (show, public, and embed).
  """

  use OnesqlxWeb, :html

  require Phoenix.LiveView

  alias Onesqlx.Dashboards.CardRenderer
  alias Onesqlx.Querying.Executor

  attr :card, :map, required: true
  attr :result, :any, required: true
  attr :exportable?, :boolean, default: false, doc: "show a CSV export button on table cards"

  def card_content(%{card: %{type: "markdown"}} = assigns) do
    content = get_in(assigns.card.config, ["content"]) || ""
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="prose prose-sm max-w-none">
      <p
        :for={line <- String.split(@content, "\n")}
        class={[
          String.starts_with?(line, "## ") && "text-lg font-bold mt-3",
          String.starts_with?(line, "# ") && "text-xl font-bold mt-4",
          String.starts_with?(line, "### ") && "text-base font-semibold mt-2",
          !String.starts_with?(line, "#") && "text-sm"
        ]}
      >
        {strip_heading_markers(line)}
      </p>
    </div>
    """
  end

  def card_content(%{result: :loading} = assigns) do
    ~H"""
    <div class="flex items-center justify-center py-8">
      <span class="loading loading-spinner loading-md"></span>
    </div>
    """
  end

  def card_content(%{result: {:error, _msg}} = assigns) do
    ~H"""
    <div class="alert alert-error text-sm">{elem(@result, 1)}</div>
    """
  end

  def card_content(%{card: %{type: "kpi"} = card, result: {:ok, result}} = assigns) do
    kpi = CardRenderer.kpi_value_for(result)
    config = card.config || %{}

    formatted =
      case kpi do
        {value, label} -> {CardRenderer.format_kpi_value(value, config), label}
        nil -> nil
      end

    assigns = assign(assigns, :kpi, formatted)

    ~H"""
    <div :if={@kpi} class="text-center py-4">
      <p class="text-4xl font-bold">{elem(@kpi, 0)}</p>
      <p class="text-sm text-base-content/60 mt-1">{elem(@kpi, 1)}</p>
    </div>
    <div :if={!@kpi} class="text-center py-4 text-base-content/50 text-sm">No data</div>
    """
  end

  def card_content(%{card: %{type: type} = card, result: {:ok, result}} = assigns)
      when type in ["bar", "line", "pie", "doughnut", "area", "scatter"] do
    chart_data = CardRenderer.chart_data_for(result)
    filter_field = get_in(card.config, ["filter_field"])

    assigns =
      assign(assigns,
        chart_data: Jason.encode!(chart_data),
        chart_type: type,
        filter_field: filter_field
      )

    ~H"""
    <div
      id={"chart-#{@card.id}"}
      phx-hook="ChartCard"
      data-chart-type={@chart_type}
      data-chart-data={@chart_data}
      data-filter-field={@filter_field}
      class="h-48"
    >
      <canvas></canvas>
    </div>
    """
  end

  def card_content(%{result: {:ok, result}} = assigns) do
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
      <form
        :if={@exportable? && @card.saved_query && @card.saved_query.data_source_id}
        action={~p"/exports/csv"}
        method="post"
        class="mt-2"
      >
        <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
        <input type="hidden" name="data_source_id" value={@card.saved_query.data_source_id} />
        <input type="hidden" name="sql" value={@card.saved_query.sql} />
        <input type="hidden" name="label" value={@card.title || @card.saved_query.title || "export"} />
        <button type="submit" class="btn btn-xs">
          <.icon name="hero-arrow-down-tray" class="size-3" /> CSV
        </button>
      </form>
    </div>
    """
  end

  defdelegate format_cell(value), to: OnesqlxWeb.CellFormatter

  @doc """
  Returns the Tailwind col-span class for a card based on its config span value.
  Default span is 2 (half of the 4-column grid).
  """
  def card_span_class(%{config: config}) do
    case config["span"] do
      1 -> "md:col-span-1"
      3 -> "md:col-span-3"
      4 -> "md:col-span-4"
      _ -> "md:col-span-2"
    end
  end

  def card_span_class(_), do: "md:col-span-2"

  defp strip_heading_markers(line) do
    String.replace(line, ~r/^\x23{1,3}\s*/, "")
  end

  def initial_card_result(%{type: "markdown"}), do: :not_applicable
  def initial_card_result(%{saved_query: %{data_source: %{}} = _sq}), do: :loading
  def initial_card_result(_card), do: {:error, "No query assigned"}

  @default_cache_ttl 300_000

  def start_card_async_tasks(socket, cards, url_params \\ %{}) do
    Enum.reduce(cards, socket, &maybe_start_card_async(&2, &1, url_params))
  end

  defp maybe_start_card_async(socket, card, url_params) do
    case card do
      %{saved_query: %{data_source: data_source, sql: sql}} when not is_nil(data_source) ->
        card_params = get_in(card.config, ["params"]) || %{}
        params = Map.merge(card_params, url_params)

        Phoenix.LiveView.start_async(socket, {:execute_card, card.id}, fn ->
          Executor.execute(data_source, sql, params: params, cache_ttl: @default_cache_ttl)
        end)

      _ ->
        socket
    end
  end
end
