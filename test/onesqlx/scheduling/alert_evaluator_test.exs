defmodule Onesqlx.Scheduling.AlertEvaluatorTest do
  use ExUnit.Case, async: true

  alias Onesqlx.Scheduling.AlertEvaluator

  describe "should_alert?/2" do
    test "errors always trigger alerts" do
      sq = %{alert_condition: "row_count_gt", alert_threshold: Decimal.new("100")}
      assert AlertEvaluator.should_alert?(sq, %{status: "error"})
    end

    test "timeouts always trigger alerts" do
      sq = %{alert_condition: "row_count_gt", alert_threshold: Decimal.new("100")}
      assert AlertEvaluator.should_alert?(sq, %{status: "timeout"})
    end

    test "nil condition always alerts" do
      sq = %{alert_condition: nil}
      assert AlertEvaluator.should_alert?(sq, %{status: "success", row_count: 5})
    end

    test "always condition alerts" do
      sq = %{alert_condition: "always"}
      assert AlertEvaluator.should_alert?(sq, %{status: "success", row_count: 5})
    end

    test "row_count_gt alerts when exceeded" do
      sq = %{alert_condition: "row_count_gt", alert_threshold: Decimal.new("10")}
      assert AlertEvaluator.should_alert?(sq, %{status: "success", row_count: 50})
    end

    test "row_count_gt does not alert when below" do
      sq = %{alert_condition: "row_count_gt", alert_threshold: Decimal.new("100")}
      refute AlertEvaluator.should_alert?(sq, %{status: "success", row_count: 5})
    end

    test "row_count_eq_zero alerts when zero rows" do
      sq = %{alert_condition: "row_count_eq_zero"}
      assert AlertEvaluator.should_alert?(sq, %{status: "success", row_count: 0})
    end

    test "row_count_eq_zero does not alert when rows exist" do
      sq = %{alert_condition: "row_count_eq_zero"}
      refute AlertEvaluator.should_alert?(sq, %{status: "success", row_count: 10})
    end

    test "value_gt alerts when first cell exceeds threshold" do
      sq = %{alert_condition: "value_gt", alert_threshold: Decimal.new("50")}
      attrs = %{status: "success", result_rows: %{"rows" => [[100, "data"]]}}
      assert AlertEvaluator.should_alert?(sq, attrs)
    end

    test "value_gt does not alert when first cell below threshold" do
      sq = %{alert_condition: "value_gt", alert_threshold: Decimal.new("50")}
      attrs = %{status: "success", result_rows: %{"rows" => [[10, "data"]]}}
      refute AlertEvaluator.should_alert?(sq, attrs)
    end

    test "value_lt alerts when first cell below threshold" do
      sq = %{alert_condition: "value_lt", alert_threshold: Decimal.new("50")}
      attrs = %{status: "success", result_rows: %{"rows" => [[10, "data"]]}}
      assert AlertEvaluator.should_alert?(sq, attrs)
    end

    test "value_lt does not alert when first cell above threshold" do
      sq = %{alert_condition: "value_lt", alert_threshold: Decimal.new("50")}
      attrs = %{status: "success", result_rows: %{"rows" => [[100, "data"]]}}
      refute AlertEvaluator.should_alert?(sq, attrs)
    end

    test "value conditions handle string numbers" do
      sq = %{alert_condition: "value_gt", alert_threshold: Decimal.new("50")}
      attrs = %{status: "success", result_rows: %{"rows" => [["100", "data"]]}}
      assert AlertEvaluator.should_alert?(sq, attrs)
    end

    test "value conditions return false for empty results" do
      sq = %{alert_condition: "value_gt", alert_threshold: Decimal.new("50")}
      attrs = %{status: "success", result_rows: %{"rows" => []}}
      refute AlertEvaluator.should_alert?(sq, attrs)
    end
  end
end
