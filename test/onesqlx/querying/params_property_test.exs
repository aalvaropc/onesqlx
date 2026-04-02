defmodule Onesqlx.Querying.ParamsPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Onesqlx.Querying.Params

  property "parameterized? returns true iff extract returns non-empty list" do
    check all(
            param_name <- string(:alphanumeric, min_length: 1, max_length: 10),
            table <- string(:alphanumeric, min_length: 3, max_length: 15)
          ) do
      sql_with_param = "SELECT * FROM #{table} WHERE col = :#{param_name}"
      sql_without_param = "SELECT * FROM #{table}"

      assert Params.parameterized?(sql_with_param) == (Params.extract(sql_with_param) != [])
      assert Params.parameterized?(sql_without_param) == (Params.extract(sql_without_param) != [])
    end
  end

  property "substitute replaces all :param_name with $N syntax" do
    check all(
            param1 <- valid_param_name(),
            param2 <- valid_param_name(),
            param1 != param2
          ) do
      sql = "SELECT * FROM t WHERE a = :#{param1} AND b = :#{param2}"
      values = %{param1 => "val1", param2 => "val2"}

      {transformed, ordered} = Params.substitute(sql, values)

      # No :param remaining in transformed SQL
      refute String.contains?(transformed, ":#{param1}")
      refute String.contains?(transformed, ":#{param2}")

      # Has $1 and $2
      assert String.contains?(transformed, "$1")
      assert String.contains?(transformed, "$2")

      # Ordered values match
      assert length(ordered) == 2
    end
  end

  property "extract is idempotent" do
    check all(
            param <- valid_param_name(),
            table <- string(:alphanumeric, min_length: 3, max_length: 15)
          ) do
      sql = "SELECT * FROM #{table} WHERE x = :#{param}"
      assert Params.extract(sql) == Params.extract(sql)
    end
  end

  property "extract returns unique names even with duplicates in SQL" do
    check all(param <- valid_param_name()) do
      sql = "SELECT * FROM t WHERE a = :#{param} OR b = :#{param} OR c = :#{param}"
      extracted = Params.extract(sql)
      assert extracted == Enum.uniq(extracted)
      assert length(extracted) == 1
    end
  end

  # Generator: valid SQL parameter names (start with letter, then alphanumeric/underscore)
  defp valid_param_name do
    gen all(
          first <- member_of(Enum.to_list(?a..?z) ++ Enum.to_list(?A..?Z)),
          rest <- string(:alphanumeric, min_length: 1, max_length: 9)
        ) do
      <<first>> <> rest
    end
  end
end
