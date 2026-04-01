defmodule OnesqlxWeb.ApiPagination do
  @moduledoc """
  Shared helpers for paginated API responses.
  """

  @default_limit 50
  @max_limit 200

  @doc """
  Extracts pagination options from controller params.

  Returns a keyword list `[limit: integer, offset: integer]` suitable
  for passing to context `list_*` functions.
  """
  def extract_pagination(params) do
    limit =
      params
      |> Map.get("limit", "#{@default_limit}")
      |> parse_int(@default_limit)
      |> clamp(1, @max_limit)

    offset =
      params
      |> Map.get("offset", "0")
      |> parse_int(0)
      |> max(0)

    [limit: limit, offset: offset]
  end

  @doc """
  Builds the pagination metadata map for a JSON response.
  """
  def pagination_meta(limit, offset, total) do
    %{limit: limit, offset: offset, total: total}
  end

  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {int, ""} -> int
      _ -> default
    end
  end

  defp parse_int(val, _default) when is_integer(val), do: val
  defp parse_int(_, default), do: default

  defp clamp(val, min, _max) when val < min, do: min
  defp clamp(val, _min, max) when val > max, do: max
  defp clamp(val, _min, _max), do: val
end
