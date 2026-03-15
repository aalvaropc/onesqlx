defmodule Onesqlx.Dashboards.CardRenderer do
  @moduledoc """
  Transforms query results into chart-friendly data structures for dashboard cards.
  """

  @doc """
  Builds a Chart.js-compatible data map from a query result.

  Returns `%{}` when the result is nil, an error tuple, or has fewer than 2 columns.
  The first column becomes labels; remaining columns become datasets.
  """
  def chart_data_for(nil), do: %{}
  def chart_data_for({:error, _type, _msg}), do: %{}

  def chart_data_for(%{columns: columns, rows: _rows}) when length(columns) < 2, do: %{}

  def chart_data_for(%{columns: [_label_col | value_cols], rows: rows}) do
    labels = Enum.map(rows, fn row -> to_string(Enum.at(row, 0)) end)

    datasets =
      value_cols
      |> Enum.with_index(1)
      |> Enum.map(fn {col_name, col_idx} ->
        %{
          label: col_name,
          data: Enum.map(rows, fn row -> Enum.at(row, col_idx) end)
        }
      end)

    %{labels: labels, datasets: datasets}
  end

  @doc """
  Extracts the KPI value from a query result.

  Returns `{value_string, column_name}` from the first cell of the first row,
  or `nil` when the result is nil, an error tuple, or has no rows.
  """
  def kpi_value_for(nil), do: nil
  def kpi_value_for({:error, _type, _msg}), do: nil
  def kpi_value_for(%{rows: []}), do: nil

  def kpi_value_for(%{columns: [col_name | _], rows: [[first_cell | _] | _]}) do
    {to_string(first_cell), col_name}
  end
end
