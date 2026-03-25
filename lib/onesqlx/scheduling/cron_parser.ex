defmodule Onesqlx.Scheduling.CronParser do
  @moduledoc """
  Minimal 5-field cron expression parser.

  Supports: `*`, numbers, ranges (`1-5`), steps (`*/5`), and comma-separated
  lists (`1,3,5`). Fields are minute, hour, day-of-month, month, day-of-week.
  """

  @field_ranges [
    {0, 59},
    {0, 23},
    {1, 31},
    {1, 12},
    {0, 6}
  ]

  @doc """
  Returns `true` if the expression is a valid 5-field cron expression.
  """
  @spec valid?(String.t()) :: boolean()
  def valid?(expression) when is_binary(expression) do
    parts = String.split(expression)

    length(parts) == 5 &&
      parts
      |> Enum.zip(@field_ranges)
      |> Enum.all?(fn {part, {min, max}} -> valid_field?(part, min, max) end)
  end

  def valid?(_), do: false

  @doc """
  Computes the next occurrence after `from` that matches the cron expression.

  Returns `{:ok, datetime}` or `{:error, reason}`.
  """
  @spec next_occurrence(String.t(), DateTime.t()) :: {:ok, DateTime.t()} | {:error, String.t()}
  def next_occurrence(expression, %DateTime{} = from) do
    case parse(expression) do
      {:ok, fields} ->
        candidate = from |> DateTime.add(60, :second) |> truncate_to_minute()
        find_next(fields, candidate, 0)

      {:error, _} = error ->
        error
    end
  end

  defp find_next(_fields, _candidate, iterations) when iterations > 525_960 do
    {:error, "no matching time found within one year"}
  end

  defp find_next(fields, candidate, iterations) do
    if matches?(fields, candidate) do
      {:ok, candidate}
    else
      next = DateTime.add(candidate, 60, :second)
      find_next(fields, next, iterations + 1)
    end
  end

  defp matches?([minutes, hours, days, months, weekdays], dt) do
    MapSet.member?(minutes, dt.minute) &&
      MapSet.member?(hours, dt.hour) &&
      MapSet.member?(days, dt.day) &&
      MapSet.member?(months, dt.month) &&
      MapSet.member?(weekdays, Date.day_of_week(dt) |> dow_to_cron())
  end

  defp dow_to_cron(7), do: 0
  defp dow_to_cron(n), do: n

  defp parse(expression) do
    parts = String.split(expression)

    if length(parts) != 5 do
      {:error, "expected 5 fields, got #{length(parts)}"}
    else
      results =
        parts
        |> Enum.zip(@field_ranges)
        |> Enum.map(fn {part, {min, max}} -> parse_field(part, min, max) end)

      case Enum.find(results, &match?({:error, _}, &1)) do
        nil -> {:ok, Enum.map(results, fn {:ok, set} -> set end)}
        error -> error
      end
    end
  end

  defp parse_field("*", min, max) do
    {:ok, MapSet.new(min..max)}
  end

  defp parse_field(field, min, max) do
    field
    |> String.split(",")
    |> Enum.reduce_while({:ok, MapSet.new()}, fn part, {:ok, acc} ->
      case parse_part(part, min, max) do
        {:ok, values} -> {:cont, {:ok, MapSet.union(acc, values)}}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp parse_part(part, min, max) do
    cond do
      String.contains?(part, "/") -> parse_step(part, min, max)
      String.contains?(part, "-") -> parse_range(part, min, max)
      true -> parse_number(part, min, max)
    end
  end

  defp parse_step(part, min, max) do
    case String.split(part, "/") do
      ["*", step_str] -> parse_wildcard_step(step_str, min, max)
      [range_str, step_str] -> parse_range_step(range_str, step_str, min, max, part)
      _ -> {:error, "invalid step expression: #{part}"}
    end
  end

  defp parse_wildcard_step(step_str, min, max) do
    case Integer.parse(step_str) do
      {step, ""} when step > 0 ->
        values = for v <- min..max, rem(v - min, step) == 0, do: v
        {:ok, MapSet.new(values)}

      _ ->
        {:error, "invalid step value: #{step_str}"}
    end
  end

  defp parse_range_step(range_str, step_str, min, max, part) do
    with {:ok, range_set} <- parse_range(range_str, min, max),
         {step, ""} when step > 0 <- Integer.parse(step_str) do
      range_list = range_set |> MapSet.to_list() |> Enum.sort()
      start = List.first(range_list)
      values = for v <- range_list, rem(v - start, step) == 0, do: v
      {:ok, MapSet.new(values)}
    else
      _ -> {:error, "invalid step expression: #{part}"}
    end
  end

  defp parse_range(part, min, max) do
    case String.split(part, "-") do
      [from_str, to_str] ->
        with {from, ""} <- Integer.parse(from_str),
             {to, ""} <- Integer.parse(to_str),
             true <- from >= min and to <= max and from <= to do
          {:ok, MapSet.new(from..to)}
        else
          _ -> {:error, "invalid range: #{part}"}
        end

      _ ->
        {:error, "invalid range: #{part}"}
    end
  end

  defp parse_number(part, min, max) do
    case Integer.parse(part) do
      {num, ""} when num >= min and num <= max ->
        {:ok, MapSet.new([num])}

      {_num, ""} ->
        {:error, "value out of range: #{part}"}

      _ ->
        {:error, "invalid number: #{part}"}
    end
  end

  defp valid_field?(field, min, max) do
    case parse_field(field, min, max) do
      {:ok, set} -> MapSet.size(set) > 0
      {:error, _} -> false
    end
  end

  defp truncate_to_minute(%DateTime{} = dt) do
    %{dt | second: 0, microsecond: {0, 0}}
  end
end
