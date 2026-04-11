defmodule Onesqlx.Querying.QueryCacheTest do
  use ExUnit.Case, async: true

  alias Onesqlx.Querying.QueryCache

  defp unique_ds_id, do: Ecto.UUID.generate()

  describe "get/3" do
    test "returns :miss for uncached query" do
      assert :miss = QueryCache.get(unique_ds_id(), "SELECT 1", %{})
    end
  end

  describe "put/5 and get/3" do
    test "caches and retrieves result" do
      ds_id = unique_ds_id()
      result = %{columns: ["id"], rows: [[1]], row_count: 1, duration_ms: 10}

      QueryCache.put(ds_id, "SELECT id FROM users", %{}, result, 60_000)

      assert {:hit, ^result} = QueryCache.get(ds_id, "SELECT id FROM users", %{})
    end

    test "different SQL returns miss" do
      ds_id = unique_ds_id()
      result = %{columns: ["id"], rows: [[1]], row_count: 1, duration_ms: 10}

      QueryCache.put(ds_id, "SELECT 1", %{}, result, 60_000)

      assert :miss = QueryCache.get(ds_id, "SELECT 2", %{})
    end

    test "different params returns miss" do
      ds_id = unique_ds_id()
      result = %{columns: ["id"], rows: [[1]], row_count: 1, duration_ms: 10}

      QueryCache.put(ds_id, "SELECT 1", %{"region" => "us"}, result, 60_000)

      assert :miss = QueryCache.get(ds_id, "SELECT 1", %{"region" => "eu"})
    end

    test "different data source returns miss" do
      ds_id = unique_ds_id()
      other_ds = unique_ds_id()
      result = %{columns: ["id"], rows: [[1]], row_count: 1, duration_ms: 10}

      QueryCache.put(ds_id, "SELECT 1", %{}, result, 60_000)

      assert :miss = QueryCache.get(other_ds, "SELECT 1", %{})
    end
  end
end
