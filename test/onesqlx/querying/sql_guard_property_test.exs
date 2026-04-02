defmodule Onesqlx.Querying.SqlGuardPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Onesqlx.Querying.SqlGuard

  @blocked_commands ~w(INSERT UPDATE DELETE ALTER DROP TRUNCATE COPY CREATE GRANT PREPARE)

  property "blocks all DML commands regardless of random casing" do
    check all(
            command <- member_of(@blocked_commands),
            table <- string(:alphanumeric, min_length: 3, max_length: 20)
          ) do
      randomized =
        command
        |> String.graphemes()
        |> Enum.map_join(fn c ->
          if :rand.uniform(2) == 1, do: String.upcase(c), else: String.downcase(c)
        end)

      sql = "#{randomized} INTO #{table} VALUES (1)"
      assert {:error, _} = SqlGuard.validate(sql)
    end
  end

  property "SELECT with random alpha table names is always safe" do
    check all(table <- string(:alphanumeric, min_length: 1, max_length: 30)) do
      sql = "SELECT * FROM #{table}"
      assert :ok = SqlGuard.validate(sql)
    end
  end

  property "safe SQL stays safe with added whitespace" do
    check all(
            spaces <- string([?\s, ?\t], min_length: 1, max_length: 5),
            table <- string(:alphanumeric, min_length: 3, max_length: 20)
          ) do
      sql = "#{spaces}SELECT#{spaces}*#{spaces}FROM#{spaces}#{table}"
      assert :ok = SqlGuard.validate(sql)
    end
  end
end
