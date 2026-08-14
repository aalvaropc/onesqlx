defmodule OnesqlxWeb.CellFormatterTest do
  use ExUnit.Case, async: true

  alias OnesqlxWeb.CellFormatter

  describe "format_cell/1" do
    test "special values" do
      assert CellFormatter.format_cell(nil) == "NULL"
      assert CellFormatter.format_cell(true) == "true"
      assert CellFormatter.format_cell(false) == "false"
    end

    test "temporal and decimal structs use canonical strings" do
      assert CellFormatter.format_cell(Decimal.new("1.50")) == "1.50"
      assert CellFormatter.format_cell(~D[2026-08-14]) == "2026-08-14"
      assert CellFormatter.format_cell(~N[2026-08-14 10:30:00]) == "2026-08-14 10:30:00"
      assert CellFormatter.format_cell(~T[10:30:00]) == "10:30:00"
      assert CellFormatter.format_cell(~U[2026-08-14 10:30:00Z]) == "2026-08-14 10:30:00Z"
    end

    test "numbers and plain strings pass through" do
      assert CellFormatter.format_cell(42) == "42"
      assert CellFormatter.format_cell(3.14) == "3.14"
      assert CellFormatter.format_cell("hello") == "hello"
    end

    test "long strings are truncated with an ellipsis" do
      long = String.duplicate("x", 600)
      formatted = CellFormatter.format_cell(long)

      assert String.ends_with?(formatted, "...")
      assert String.length(formatted) == 503
    end

    test "other terms are inspected" do
      assert CellFormatter.format_cell(%{a: 1}) == "%{a: 1}"
    end
  end

  describe "truncated?/1 and raw_cell/1" do
    test "truncated? only for long binaries" do
      refute CellFormatter.truncated?("short")
      refute CellFormatter.truncated?(123)
      assert CellFormatter.truncated?(String.duplicate("x", 501))
    end

    test "raw_cell returns the full value" do
      long = String.duplicate("x", 600)
      assert CellFormatter.raw_cell(long) == long
      assert CellFormatter.raw_cell(123) == "123"
    end
  end

  describe "sort_rows/3" do
    test "nil column keeps original order" do
      rows = [[3], [1], [2]]
      assert CellFormatter.sort_rows(rows, nil, :asc) == rows
    end

    test "sorts numbers ascending and descending" do
      rows = [[3, "c"], [1, "a"], [2, "b"]]

      assert CellFormatter.sort_rows(rows, 0, :asc) == [[1, "a"], [2, "b"], [3, "c"]]
      assert CellFormatter.sort_rows(rows, 0, :desc) == [[3, "c"], [2, "b"], [1, "a"]]
    end

    test "sorts strings case-insensitively" do
      rows = [["b"], ["A"], ["c"]]
      assert CellFormatter.sort_rows(rows, 0, :asc) == [["A"], ["b"], ["c"]]
    end

    test "nils sort first, then numbers, then strings" do
      rows = [["z"], [nil], [5], [Decimal.new("2.5")]]

      assert CellFormatter.sort_rows(rows, 0, :asc) ==
               [[nil], [Decimal.new("2.5")], [5], ["z"]]
    end
  end
end
