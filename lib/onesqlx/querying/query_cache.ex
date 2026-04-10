defmodule Onesqlx.Querying.QueryCache do
  @moduledoc """
  In-memory cache for query results using Cachex.

  Caches successful query results keyed by data source, SQL, and parameters.
  Used by dashboard card execution to avoid repeated database hits.
  """

  @cache_name :query_cache

  @doc """
  Looks up a cached query result.

  Returns `{:hit, result}` if cached, `:miss` otherwise.
  """
  def get(data_source_id, sql, params) do
    key = cache_key(data_source_id, sql, params)

    case Cachex.get(@cache_name, key) do
      {:ok, nil} -> :miss
      {:ok, result} -> {:hit, result}
      _ -> :miss
    end
  end

  @doc """
  Stores a query result in the cache with the given TTL in milliseconds.
  """
  def put(data_source_id, sql, params, result, ttl_ms) do
    key = cache_key(data_source_id, sql, params)
    Cachex.put(@cache_name, key, result, ttl: ttl_ms)
    :ok
  end

  defp cache_key(data_source_id, sql, params) do
    sql_hash = :erlang.phash2(sql)
    params_hash = :erlang.phash2(params)
    "ds:#{data_source_id}:#{sql_hash}:#{params_hash}"
  end
end
