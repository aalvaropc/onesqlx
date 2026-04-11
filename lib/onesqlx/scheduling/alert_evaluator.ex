defmodule Onesqlx.Scheduling.AlertEvaluator do
  @moduledoc """
  Evaluates alert conditions against scheduled query run results.

  Determines whether notifications should be sent based on the configured
  alert condition and threshold.
  """

  @doc """
  Returns `true` if the run result meets the alert condition.

  Errors and timeouts always trigger alerts. For successful runs,
  the configured condition is evaluated against the result.
  """
  def should_alert?(scheduled_query, run_attrs)

  def should_alert?(_sq, %{status: status}) when status in ["error", "timeout"], do: true

  def should_alert?(%{alert_condition: nil}, _run_attrs), do: true
  def should_alert?(%{alert_condition: "always"}, _run_attrs), do: true

  def should_alert?(%{alert_condition: "row_count_gt", alert_threshold: threshold}, run_attrs) do
    (run_attrs[:row_count] || 0) > to_number(threshold)
  end

  def should_alert?(%{alert_condition: "row_count_eq_zero"}, run_attrs) do
    (run_attrs[:row_count] || 0) == 0
  end

  def should_alert?(%{alert_condition: "value_gt", alert_threshold: threshold}, run_attrs) do
    case first_cell_value(run_attrs) do
      nil -> false
      value -> value > to_number(threshold)
    end
  end

  def should_alert?(%{alert_condition: "value_lt", alert_threshold: threshold}, run_attrs) do
    case first_cell_value(run_attrs) do
      nil -> false
      value -> value < to_number(threshold)
    end
  end

  def should_alert?(_, _), do: true

  defp first_cell_value(run_attrs) do
    case get_in(run_attrs, [:result_rows, "rows"]) do
      [[first | _] | _] when is_number(first) -> first
      [[first | _] | _] when is_binary(first) -> parse_number(first)
      _ -> nil
    end
  end

  defp parse_number(str) do
    case Float.parse(str) do
      {num, _} -> num
      :error -> nil
    end
  end

  defp to_number(nil), do: 0
  defp to_number(%Decimal{} = d), do: Decimal.to_float(d)
  defp to_number(n) when is_number(n), do: n
  defp to_number(_), do: 0
end
