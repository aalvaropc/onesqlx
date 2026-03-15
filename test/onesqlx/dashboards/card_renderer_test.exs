defmodule Onesqlx.Dashboards.CardRendererTest do
  use ExUnit.Case, async: true

  alias Onesqlx.Dashboards.CardRenderer

  describe "chart_data_for/1" do
    test "returns %{} for nil" do
      assert CardRenderer.chart_data_for(nil) == %{}
    end

    test "returns %{} for error tuple" do
      assert CardRenderer.chart_data_for({:error, :execution, "boom"}) == %{}
    end

    test "returns %{} for single-column result" do
      result = %{columns: ["name"], rows: [["alice"], ["bob"]]}
      assert CardRenderer.chart_data_for(result) == %{}
    end

    test "returns correct labels and datasets for 2-column result" do
      result = %{columns: ["month", "sales"], rows: [["Jan", 100], ["Feb", 200]]}

      assert %{labels: ["Jan", "Feb"], datasets: [%{label: "sales", data: [100, 200]}]} =
               CardRenderer.chart_data_for(result)
    end

    test "produces multiple datasets for multi-column result" do
      result = %{
        columns: ["month", "sales", "returns"],
        rows: [["Jan", 100, 5], ["Feb", 200, 10]]
      }

      %{labels: labels, datasets: datasets} = CardRenderer.chart_data_for(result)
      assert labels == ["Jan", "Feb"]
      assert length(datasets) == 2
      assert Enum.find(datasets, &(&1.label == "sales")).data == [100, 200]
      assert Enum.find(datasets, &(&1.label == "returns")).data == [5, 10]
    end

    test "coerces label column to string" do
      result = %{columns: ["id", "count"], rows: [[1, 42], [2, 99]]}
      %{labels: labels} = CardRenderer.chart_data_for(result)
      assert labels == ["1", "2"]
    end
  end

  describe "kpi_value_for/1" do
    test "returns nil for nil" do
      assert CardRenderer.kpi_value_for(nil) == nil
    end

    test "returns nil for error tuple" do
      assert CardRenderer.kpi_value_for({:error, :execution, "boom"}) == nil
    end

    test "returns nil for empty rows" do
      assert CardRenderer.kpi_value_for(%{columns: ["count"], rows: []}) == nil
    end

    test "returns {value, column_name} for valid result" do
      result = %{columns: ["total_revenue"], rows: [[42_000]]}
      assert CardRenderer.kpi_value_for(result) == {"42000", "total_revenue"}
    end

    test "coerces value to string" do
      result = %{columns: ["rate"], rows: [[3.14]]}
      assert {"3.14", "rate"} = CardRenderer.kpi_value_for(result)
    end
  end
end
