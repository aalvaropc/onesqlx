defmodule OnesqlxWeb.CellFormatter do
  @moduledoc """
  Formatting and sorting helpers for query-result cells, shared by the
  SQL editor and dashboard result tables.
  """

  @truncate_at 500

  @doc """
  Formats a result cell for display. `nil` renders as `NULL`, common
  temporal/decimal structs use their canonical string form, and long
  strings are truncated at #{@truncate_at} characters (see `truncated?/1`
  and `raw_cell/1` for the full value).
  """
  def format_cell(nil), do: "NULL"
  def format_cell(true), do: "true"
  def format_cell(false), do: "false"
  def format_cell(%Decimal{} = value), do: Decimal.to_string(value)
  def format_cell(%Date{} = value), do: Date.to_string(value)
  def format_cell(%DateTime{} = value), do: DateTime.to_string(value)
  def format_cell(%NaiveDateTime{} = value), do: NaiveDateTime.to_string(value)
  def format_cell(%Time{} = value), do: Time.to_string(value)

  def format_cell(value) when is_binary(value) do
    if String.length(value) > @truncate_at do
      String.slice(value, 0, @truncate_at) <> "..."
    else
      value
    end
  end

  def format_cell(value) when is_number(value), do: to_string(value)
  def format_cell(value), do: inspect(value)

  @doc "Whether `format_cell/1` truncates this value."
  def truncated?(value) when is_binary(value), do: String.length(value) > @truncate_at
  def truncated?(_), do: false

  @doc "The untruncated string representation of a cell."
  def raw_cell(value) when is_binary(value), do: value
  def raw_cell(value), do: inspect(value)

  @doc """
  Sorts result rows by the value at `column` (nil column = original
  order). Values sort in type groups: nils first, then numbers, then
  strings case-insensitively, then everything else by string form.
  """
  def sort_rows(rows, nil, _direction), do: rows

  def sort_rows(rows, column, direction) do
    sorted = Enum.sort_by(rows, fn row -> row |> Enum.at(column) |> sort_key() end)

    if direction == :desc, do: Enum.reverse(sorted), else: sorted
  end

  defp sort_key(nil), do: {0, ""}
  defp sort_key(val) when is_number(val), do: {1, val}
  defp sort_key(%Decimal{} = val), do: {1, Decimal.to_float(val)}
  defp sort_key(val) when is_binary(val), do: {2, String.downcase(val)}
  defp sort_key(val), do: {3, to_string(val)}
end
