defmodule Onesqlx.Querying.SqlGuardTest do
  use ExUnit.Case, async: true

  alias Onesqlx.Querying.SqlGuard

  describe "validate/1" do
    test "allows SELECT statements" do
      assert :ok = SqlGuard.validate("SELECT * FROM users")
      assert :ok = SqlGuard.validate("SELECT 1")
      assert :ok = SqlGuard.validate("select id, name from users where id = 1")
    end

    test "allows EXPLAIN statements" do
      assert :ok = SqlGuard.validate("EXPLAIN SELECT * FROM users")
      assert :ok = SqlGuard.validate("EXPLAIN ANALYZE SELECT * FROM users")
    end

    test "allows CTEs with SELECT" do
      sql = """
      WITH active_users AS (
        SELECT * FROM users WHERE active = true
      )
      SELECT * FROM active_users
      """

      assert :ok = SqlGuard.validate(sql)
    end

    test "allows multiple CTEs with SELECT" do
      sql = """
      WITH
        cte1 AS (SELECT 1),
        cte2 AS (SELECT 2)
      SELECT * FROM cte1, cte2
      """

      assert :ok = SqlGuard.validate(sql)
    end

    test "allows keywords inside string literals" do
      assert :ok = SqlGuard.validate("SELECT 'INSERT'")
      assert :ok = SqlGuard.validate("SELECT 'DROP TABLE users'")
      assert :ok = SqlGuard.validate("SELECT * FROM users WHERE name = 'DELETE ME'")
    end

    test "allows keywords inside comments" do
      assert :ok = SqlGuard.validate("SELECT 1 -- INSERT INTO users")
      assert :ok = SqlGuard.validate("SELECT 1 /* DROP TABLE users */")

      sql = """
      /* This query does not INSERT anything */
      SELECT * FROM users
      """

      assert :ok = SqlGuard.validate(sql)
    end

    test "allows keywords in double-quoted identifiers" do
      assert :ok = SqlGuard.validate(~s|SELECT * FROM "DROP"|)
    end

    test "allows empty or whitespace-only input" do
      assert :ok = SqlGuard.validate("")
      assert :ok = SqlGuard.validate("   ")
      assert :ok = SqlGuard.validate("\n\t")
    end

    test "blocks INSERT statements" do
      assert {:error, msg} = SqlGuard.validate("INSERT INTO users (name) VALUES ('test')")
      assert msg =~ "INSERT"
    end

    test "blocks UPDATE statements" do
      assert {:error, msg} = SqlGuard.validate("UPDATE users SET name = 'test'")
      assert msg =~ "UPDATE"
    end

    test "blocks DELETE statements" do
      assert {:error, msg} = SqlGuard.validate("DELETE FROM users WHERE id = 1")
      assert msg =~ "DELETE"
    end

    test "blocks ALTER statements" do
      assert {:error, msg} = SqlGuard.validate("ALTER TABLE users ADD COLUMN age integer")
      assert msg =~ "ALTER"
    end

    test "blocks DROP statements" do
      assert {:error, msg} = SqlGuard.validate("DROP TABLE users")
      assert msg =~ "DROP"
    end

    test "blocks TRUNCATE statements" do
      assert {:error, msg} = SqlGuard.validate("TRUNCATE users")
      assert msg =~ "TRUNCATE"
    end

    test "blocks COPY statements" do
      assert {:error, msg} = SqlGuard.validate("COPY users FROM '/tmp/data.csv'")
      assert msg =~ "COPY"
    end

    test "blocks case-insensitive commands" do
      assert {:error, _} = SqlGuard.validate("insert into users values (1)")
      assert {:error, _} = SqlGuard.validate("Update users set x = 1")
      assert {:error, _} = SqlGuard.validate("dElEtE from users")
    end

    test "blocks whitespace-prefixed commands" do
      assert {:error, _} = SqlGuard.validate("   INSERT INTO users VALUES (1)")
      assert {:error, _} = SqlGuard.validate("\n\tDROP TABLE users")
    end

    test "blocks WITH...INSERT (CTE with write)" do
      sql = """
      WITH new_data AS (
        SELECT 1 AS id
      )
      INSERT INTO users SELECT * FROM new_data
      """

      assert {:error, msg} = SqlGuard.validate(sql)
      assert msg =~ "INSERT"
    end

    test "blocks WITH...UPDATE" do
      sql = """
      WITH cte AS (SELECT 1)
      UPDATE users SET name = 'x'
      """

      assert {:error, msg} = SqlGuard.validate(sql)
      assert msg =~ "UPDATE"
    end

    test "blocks WITH...DELETE" do
      sql = """
      WITH cte AS (SELECT 1)
      DELETE FROM users
      """

      assert {:error, msg} = SqlGuard.validate(sql)
      assert msg =~ "DELETE"
    end

    test "blocks multi-statement with dangerous command" do
      assert {:error, _} = SqlGuard.validate("SELECT 1; DROP TABLE users")
      assert {:error, _} = SqlGuard.validate("SELECT 1; INSERT INTO users VALUES (1)")
    end

    test "allows multi-statement with only SELECT" do
      assert :ok = SqlGuard.validate("SELECT 1; SELECT 2")
    end

    test "handles escaped quotes in string literals" do
      assert :ok = SqlGuard.validate("SELECT 'it''s a DELETE test'")
    end
  end

  describe "safe?/1" do
    test "returns true for safe SQL" do
      assert SqlGuard.safe?("SELECT 1")
    end

    test "returns false for dangerous SQL" do
      refute SqlGuard.safe?("DROP TABLE users")
    end
  end
end
