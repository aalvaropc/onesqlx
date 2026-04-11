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

  @doc """
  Formats a KPI value string with thousands separators and optional prefix/suffix.

  Reads `"prefix"` and `"suffix"` from the card config map.

  ## Examples

      iex> format_kpi_value("42000", %{})
      "42,000"

      iex> format_kpi_value("1500.50", %{"prefix" => "$"})
      "$1,500.50"

      iex> format_kpi_value("85", %{"suffix" => "%"})
      "85%"
  """
  def format_kpi_value(value, config \\ %{})

  def format_kpi_value(value, config) when is_binary(value) do
    prefix = config["prefix"] || ""
    suffix = config["suffix"] || ""
    formatted = format_number_string(value)
    "#{prefix}#{formatted}#{suffix}"
  end

  def format_kpi_value(value, config), do: format_kpi_value(to_string(value), config)

  defp format_number_string(value) do
    case parse_number_parts(value) do
      {:ok, integer_part, decimal_part} ->
        formatted_int = add_thousands_separator(integer_part)

        if decimal_part do
          "#{formatted_int}.#{decimal_part}"
        else
          formatted_int
        end

      :not_a_number ->
        value
    end
  end

  defp parse_number_parts(value) do
    trimmed = String.trim(value)

    case Regex.run(~r/\A-?(\d+)(?:\.(\d+))?\z/, trimmed) do
      [_, integer_part] ->
        prefix = if String.starts_with?(trimmed, "-"), do: "-", else: ""
        {:ok, prefix <> integer_part, nil}

      [_, integer_part, decimal_part] ->
        prefix = if String.starts_with?(trimmed, "-"), do: "-", else: ""
        {:ok, prefix <> integer_part, decimal_part}

      nil ->
        :not_a_number
    end
  end

  defp add_thousands_separator(integer_str) do
    {sign, digits} =
      if String.starts_with?(integer_str, "-") do
        {"-", String.trim_leading(integer_str, "-")}
      else
        {"", integer_str}
      end

    formatted =
      digits
      |> String.reverse()
      |> String.graphemes()
      |> Enum.chunk_every(3)
      |> Enum.join(",")
      |> String.reverse()

    sign <> formatted
  end
end
