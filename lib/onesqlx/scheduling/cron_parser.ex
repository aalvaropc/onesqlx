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

  # Deterministic field-by-field algorithm — O(366) worst case instead of O(525K)
  defp find_next([minutes, hours, days, months, weekdays], candidate, _iterations) do
    sorted = %{
      minutes: sorted_set(minutes),
      hours: sorted_set(hours),
      days: sorted_set(days),
      months: sorted_set(months),
      weekdays: weekdays
    }

    advance_month(candidate, sorted, 0)
  end

  defp advance_month(_dt, _s, attempts) when attempts > 24 do
    {:error, "no matching time found within one year"}
  end

  defp advance_month(dt, s, attempts) do
    case next_in_list(dt.month, s.months) do
      {:ok, month} when month == dt.month ->
        advance_day(dt, s, 0)

      {:ok, month} ->
        dt = reset_to(dt, month, hd(s.days), hd(s.hours), hd(s.minutes))
        advance_day(dt, s, 0)

      :overflow ->
        dt =
          %{dt | year: dt.year + 1}
          |> reset_to(hd(s.months), hd(s.days), hd(s.hours), hd(s.minutes))

        advance_month(dt, s, attempts + 1)
    end
  end

  defp advance_day(_dt, _s, attempts) when attempts > 366 do
    {:error, "no matching time found within one year"}
  end

  defp advance_day(dt, s, attempts) do
    day_valid = MapSet.member?(MapSet.new(s.days), dt.day)
    dow_valid = MapSet.member?(s.weekdays, dow_to_cron(Date.day_of_week(dt)))

    if day_valid && dow_valid do
      advance_hour(dt, s)
    else
      next_dt = DateTime.add(dt, 86_400, :second)
      next_dt = reset_to(next_dt, next_dt.month, next_dt.day, hd(s.hours), hd(s.minutes))

      if next_dt.month != dt.month do
        advance_month(next_dt, s, 0)
      else
        advance_day(next_dt, s, attempts + 1)
      end
    end
  end

  defp advance_hour(dt, s) do
    case next_in_list(dt.hour, s.hours) do
      {:ok, hour} when hour == dt.hour ->
        advance_minute(dt, s)

      {:ok, hour} ->
        dt = %{dt | hour: hour, minute: hd(s.minutes), second: 0, microsecond: {0, 0}}
        {:ok, dt}

      :overflow ->
        next_dt = DateTime.add(dt, 86_400, :second)
        next_dt = reset_to(next_dt, next_dt.month, next_dt.day, hd(s.hours), hd(s.minutes))

        if next_dt.month != dt.month do
          advance_month(next_dt, s, 0)
        else
          advance_day(next_dt, s, 0)
        end
    end
  end

  defp advance_minute(dt, s) do
    case next_in_list(dt.minute, s.minutes) do
      {:ok, minute} ->
        {:ok, %{dt | minute: minute, second: 0, microsecond: {0, 0}}}

      :overflow ->
        dt = %{dt | minute: hd(s.minutes), second: 0, microsecond: {0, 0}}
        next_hour_dt = DateTime.add(dt, 3600, :second)
        next_hour_dt = %{next_hour_dt | minute: hd(s.minutes), second: 0, microsecond: {0, 0}}

        if next_hour_dt.month != dt.month do
          advance_month(next_hour_dt, s, 0)
        else
          advance_day(next_hour_dt, s, 0)
        end
    end
  end

  defp next_in_list(current, sorted_values) do
    case Enum.find(sorted_values, fn v -> v >= current end) do
      nil -> :overflow
      val -> {:ok, val}
    end
  end

  defp sorted_set(mapset), do: mapset |> MapSet.to_list() |> Enum.sort()

  defp reset_to(dt, month, day, hour, minute) do
    day = min(day, Calendar.ISO.days_in_month(dt.year, month))
    %{dt | month: month, day: day, hour: hour, minute: minute, second: 0, microsecond: {0, 0}}
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
