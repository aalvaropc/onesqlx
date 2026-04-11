defmodule Onesqlx.LineageTest do
  use Onesqlx.DataCase, async: true

  alias Onesqlx.Lineage

  describe "extract_tables/1" do
    test "extracts table from simple SELECT" do
      assert [{"public", "users"}] = Lineage.extract_tables("SELECT * FROM users")
    end

    test "extracts schema-qualified table" do
      assert [{"analytics", "events"}] =
               Lineage.extract_tables("SELECT * FROM analytics.events")
    end

    test "extracts tables from JOINs" do
      sql = "SELECT * FROM orders JOIN customers ON orders.customer_id = customers.id"
      tables = Lineage.extract_tables(sql)
      assert {"public", "orders"} in tables
      assert {"public", "customers"} in tables
    end

    test "extracts tables from LEFT JOIN" do
      sql = "SELECT * FROM products LEFT JOIN categories ON products.cat_id = categories.id"
      tables = Lineage.extract_tables(sql)
      assert {"public", "products"} in tables
      assert {"public", "categories"} in tables
    end

    test "deduplicates table references" do
      sql = "SELECT * FROM users JOIN users ON true"
      assert [{"public", "users"}] = Lineage.extract_tables(sql)
    end

    test "ignores tables in string literals" do
      sql = "SELECT 'FROM secret_table' FROM users"
      assert [{"public", "users"}] = Lineage.extract_tables(sql)
    end

    test "ignores tables in comments" do
      sql = """
      SELECT * FROM users
      -- FROM hidden_table
      /* FROM another_table */
      """

      assert [{"public", "users"}] = Lineage.extract_tables(sql)
    end

    test "excludes CTE names" do
      sql = """
      WITH recent AS (
        SELECT * FROM orders WHERE created_at > now() - interval '7 days'
      )
      SELECT * FROM recent JOIN users ON recent.user_id = users.id
      """

      tables = Lineage.extract_tables(sql)
      assert {"public", "orders"} in tables
      assert {"public", "users"} in tables
      refute Enum.any?(tables, fn {_, name} -> name == "recent" end)
    end

    test "handles multiple CTEs" do
      sql = """
      WITH cte1 AS (SELECT * FROM orders),
           cte2 AS (SELECT * FROM products)
      SELECT * FROM cte1 JOIN cte2 ON true
      """

      tables = Lineage.extract_tables(sql)
      assert {"public", "orders"} in tables
      assert {"public", "products"} in tables
      refute Enum.any?(tables, fn {_, name} -> name in ["cte1", "cte2"] end)
    end

    test "excludes SQL keywords like LATERAL" do
      sql = "SELECT * FROM orders, LATERAL generate_series(1, 10)"
      tables = Lineage.extract_tables(sql)
      assert {"public", "orders"} in tables
    end

    test "returns empty list for nil" do
      assert [] = Lineage.extract_tables(nil)
    end

    test "returns empty list for empty string" do
      assert [] = Lineage.extract_tables("")
    end
  end
end
