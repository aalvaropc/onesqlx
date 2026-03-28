defmodule Onesqlx.Export.Csv do
  @moduledoc """
  Generates RFC 4180-compliant CSV content from query results.

  Returns iodata for efficient streaming to the client.
  """

  @doc """
  Encodes query result columns and rows into CSV iodata.
  """
  @spec encode(%{columns: [String.t()], rows: [[term()]]}) :: iodata()
  def encode(%{columns: columns, rows: rows}) do
    header = encode_row(columns)
    body = Enum.map(rows, &encode_row/1)
    Enum.intersperse([header | body], "\r\n")
  end

  @doc """
  Returns a safe filename for CSV export with a timestamp suffix.
  """
  @spec filename(String.t()) :: String.t()
  def filename(label) do
    timestamp = Calendar.strftime(DateTime.utc_now(), "%Y%m%d_%H%M%S")

    safe_label =
      label
      |> String.replace(~r/[^a-zA-Z0-9_-]/, "_")
      |> String.slice(0, 50)

    "#{safe_label}_#{timestamp}.csv"
  end

  defp encode_row(cells) do
    cells
    |> Enum.map(&encode_cell/1)
    |> Enum.intersperse(",")
  end

  defp encode_cell(nil), do: ""
  defp encode_cell(true), do: "true"
  defp encode_cell(false), do: "false"

  defp encode_cell(value) when is_binary(value) do
    if needs_quoting?(value) do
      [?", String.replace(value, "\"", "\"\""), ?"]
    else
      value
    end
  end

  defp encode_cell(value), do: encode_cell(to_string(value))

  defp needs_quoting?(value) do
    String.contains?(value, [",", "\"", "\n", "\r"])
  end
end
