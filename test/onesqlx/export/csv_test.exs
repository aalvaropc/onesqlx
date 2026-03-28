defmodule Onesqlx.Export.CsvTest do
  use ExUnit.Case, async: true

  alias Onesqlx.Export.Csv

  describe "encode/1" do
    test "encodes simple table" do
      result = %{columns: ["id", "name"], rows: [[1, "alice"], [2, "bob"]]}
      csv = result |> Csv.encode() |> IO.iodata_to_binary()
      assert csv == "id,name\r\n1,alice\r\n2,bob"
    end

    test "handles nil values as empty string" do
      result = %{columns: ["a", "b"], rows: [[1, nil]]}
      csv = result |> Csv.encode() |> IO.iodata_to_binary()
      assert csv == "a,b\r\n1,"
    end

    test "handles boolean values" do
      result = %{columns: ["flag"], rows: [[true], [false]]}
      csv = result |> Csv.encode() |> IO.iodata_to_binary()
      assert csv == "flag\r\ntrue\r\nfalse"
    end

    test "quotes values containing commas" do
      result = %{columns: ["text"], rows: [["hello, world"]]}
      csv = result |> Csv.encode() |> IO.iodata_to_binary()
      assert csv == "text\r\n\"hello, world\""
    end

    test "escapes quotes by doubling" do
      result = %{columns: ["text"], rows: [["say \"hi\""]]}
      csv = result |> Csv.encode() |> IO.iodata_to_binary()
      assert csv == "text\r\n\"say \"\"hi\"\"\""
    end

    test "quotes values containing newlines" do
      result = %{columns: ["text"], rows: [["line1\nline2"]]}
      csv = result |> Csv.encode() |> IO.iodata_to_binary()
      assert csv == "text\r\n\"line1\nline2\""
    end

    test "handles empty rows" do
      result = %{columns: ["a", "b"], rows: []}
      csv = result |> Csv.encode() |> IO.iodata_to_binary()
      assert csv == "a,b"
    end

    test "handles integer and float values" do
      result = %{columns: ["int", "float"], rows: [[42, 3.14]]}
      csv = result |> Csv.encode() |> IO.iodata_to_binary()
      assert csv == "int,float\r\n42,3.14"
    end
  end

  describe "filename/1" do
    test "generates filename with safe characters" do
      name = Csv.filename("My Report!")
      assert name =~ ~r/^My_Report__\d{8}_\d{6}\.csv$/
    end

    test "truncates long labels to 50 chars" do
      long = String.duplicate("a", 100)
      name = Csv.filename(long)
      # 50 chars label + _ + 15 chars timestamp + .csv
      assert String.length(name) <= 70
    end

    test "generates unique filenames" do
      name1 = Csv.filename("test")
      name2 = Csv.filename("test")
      # Same second might produce same name, but format is consistent
      assert name1 =~ ~r/^test_\d{8}_\d{6}\.csv$/
      assert name2 =~ ~r/^test_\d{8}_\d{6}\.csv$/
    end
  end
end
