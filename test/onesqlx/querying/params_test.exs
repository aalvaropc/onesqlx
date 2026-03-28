defmodule Onesqlx.Querying.ParamsTest do
  use ExUnit.Case, async: true

  alias Onesqlx.Querying.Params

  describe "extract/1" do
    test "extracts params from simple query" do
      sql = "SELECT * FROM users WHERE region = :region AND status = :status"
      assert Params.extract(sql) == ["region", "status"]
    end

    test "ignores params inside string literals" do
      sql = "SELECT ':not_a_param' FROM users WHERE id = :id"
      assert Params.extract(sql) == ["id"]
    end

    test "ignores PostgreSQL cast syntax" do
      sql = "SELECT id::text, name::varchar FROM users WHERE id = :id"
      assert Params.extract(sql) == ["id"]
    end

    test "deduplicates parameters" do
      sql = "SELECT * FROM users WHERE a = :x OR b = :x"
      assert Params.extract(sql) == ["x"]
    end

    test "preserves order of first appearance" do
      sql = "SELECT * FROM t WHERE b = :beta AND a = :alpha AND c = :beta"
      assert Params.extract(sql) == ["beta", "alpha"]
    end

    test "returns empty list for no params" do
      assert Params.extract("SELECT 1") == []
    end

    test "returns empty list for empty string" do
      assert Params.extract("") == []
    end

    test "handles underscores in param names" do
      sql = "SELECT * FROM t WHERE col = :my_param_1"
      assert Params.extract(sql) == ["my_param_1"]
    end
  end

  describe "substitute/2" do
    test "produces correct positional SQL and values" do
      sql = "SELECT * FROM users WHERE region = :region AND status = :status"
      values = %{"region" => "US", "status" => "active"}

      {transformed, ordered} = Params.substitute(sql, values)
      assert transformed == "SELECT * FROM users WHERE region = $1 AND status = $2"
      assert ordered == ["US", "active"]
    end

    test "reuses same positional param for duplicate references" do
      sql = "SELECT * FROM t WHERE a = :x OR b = :x"
      values = %{"x" => 42}

      {transformed, ordered} = Params.substitute(sql, values)
      assert transformed == "SELECT * FROM t WHERE a = $1 OR b = $1"
      assert ordered == [42]
    end

    test "raises on missing parameter value" do
      sql = "SELECT * FROM t WHERE a = :missing"

      assert_raise ArgumentError, ~r/missing value for parameter :missing/, fn ->
        Params.substitute(sql, %{})
      end
    end

    test "handles multiple distinct params" do
      sql = "SELECT * FROM t WHERE a = :x AND b = :y AND c = :z"
      values = %{"x" => 1, "y" => 2, "z" => 3}

      {transformed, ordered} = Params.substitute(sql, values)
      assert transformed == "SELECT * FROM t WHERE a = $1 AND b = $2 AND c = $3"
      assert ordered == [1, 2, 3]
    end

    test "does not substitute inside string literals" do
      sql = "SELECT ':literal' FROM t WHERE id = :id"
      values = %{"id" => 5}

      {transformed, ordered} = Params.substitute(sql, values)
      assert transformed =~ "':literal'"
      assert transformed =~ "$1"
      assert ordered == [5]
    end
  end

  describe "parameterized?/1" do
    test "returns true for parameterized SQL" do
      assert Params.parameterized?("SELECT * FROM t WHERE id = :id")
    end

    test "returns false for plain SQL" do
      refute Params.parameterized?("SELECT 1")
    end

    test "returns false for cast-only syntax" do
      refute Params.parameterized?("SELECT id::text FROM t")
    end
  end
end
