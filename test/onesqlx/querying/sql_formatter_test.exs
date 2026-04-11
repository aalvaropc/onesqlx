defmodule Onesqlx.Querying.SqlFormatterTest do
  use ExUnit.Case, async: true

  alias Onesqlx.Querying.SqlFormatter

  describe "format/1" do
    test "uppercases SQL keywords" do
      result = SqlFormatter.format("select id from users where active = true")
      assert result =~ "SELECT"
      assert result =~ "FROM"
      assert result =~ "WHERE"
    end

    test "breaks major clauses onto new lines" do
      result = SqlFormatter.format("select id from users where active = true")
      lines = String.split(result, "\n")
      assert length(lines) >= 3
    end

    test "handles JOINs" do
      sql =
        "select u.id, o.total from users u join orders o on u.id = o.user_id where u.active = true"

      result = SqlFormatter.format(sql)
      assert result =~ "JOIN"
      assert result =~ "ON"
    end

    test "handles GROUP BY and ORDER BY" do
      sql =
        "select category, count(*) from products group by category order by count(*) desc limit 10"

      result = SqlFormatter.format(sql)
      assert result =~ "GROUP"
      assert result =~ "ORDER"
      assert result =~ "LIMIT"
    end

    test "normalizes whitespace" do
      sql = "select   id    from   users    where   active = true"
      result = SqlFormatter.format(sql)
      refute result =~ "   "
    end

    test "handles empty string" do
      assert SqlFormatter.format("") == ""
    end

    test "preserves non-keyword text" do
      result = SqlFormatter.format("select username, email from users")
      assert result =~ "username"
      assert result =~ "email"
      assert result =~ "users"
    end
  end
end
