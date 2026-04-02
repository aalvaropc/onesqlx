defmodule Onesqlx.Scheduling.CronParserPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Onesqlx.Scheduling.CronParser

  @valid_expressions [
    "* * * * *",
    "0 * * * *",
    "0 0 * * *",
    "0 0 * * 1",
    "*/5 * * * *",
    "*/15 * * * *",
    "0 9-17 * * 1-5",
    "0 0 1,15 * *",
    "30 6 * * *"
  ]

  property "next_occurrence always returns a time strictly after input" do
    check all(
            expression <- member_of(@valid_expressions),
            days_offset <- integer(0..364)
          ) do
      from = DateTime.add(~U[2026-01-01 00:00:00Z], days_offset * 86_400, :second)

      case CronParser.next_occurrence(expression, from) do
        {:ok, result} ->
          assert DateTime.compare(result, from) == :gt

        {:error, _} ->
          :ok
      end
    end
  end

  property "next_occurrence result minute and hour are valid for the expression" do
    check all(expression <- member_of(@valid_expressions)) do
      from = ~U[2026-06-15 12:30:00Z]

      case CronParser.next_occurrence(expression, from) do
        {:ok, result} ->
          # Parse expression to get valid sets
          [min_field, hour_field | _] = String.split(expression)

          if min_field != "*" do
            valid_minutes = parse_field_values(min_field, 0, 59)
            assert result.minute in valid_minutes
          end

          if hour_field != "*" do
            valid_hours = parse_field_values(hour_field, 0, 23)
            assert result.hour in valid_hours
          end

        {:error, _} ->
          :ok
      end
    end
  end

  property "valid? is deterministic" do
    check all(expression <- string(:printable, min_length: 1, max_length: 30)) do
      result1 = CronParser.valid?(expression)
      result2 = CronParser.valid?(expression)
      assert result1 == result2
    end
  end

  defp parse_field_values(field, min, max) do
    cond do
      String.contains?(field, "/") ->
        [_, step_str] = String.split(field, "/")
        {step, _} = Integer.parse(step_str)
        for v <- min..max, rem(v - min, step) == 0, do: v

      String.contains?(field, "-") ->
        [from_str, to_str] = String.split(field, "-")
        {from, _} = Integer.parse(from_str)
        {to, _} = Integer.parse(to_str)
        Enum.to_list(from..to)

      String.contains?(field, ",") ->
        field |> String.split(",") |> Enum.map(fn s -> s |> Integer.parse() |> elem(0) end)

      true ->
        case Integer.parse(field) do
          {n, _} -> [n]
          :error -> Enum.to_list(min..max)
        end
    end
  end
end
