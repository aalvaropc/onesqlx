defmodule OnesqlxWeb.Plugs.RateLimit do
  @moduledoc """
  Token-based rate limiting plug using ETS.

  Tracks request counts per API user per time window.
  Returns 429 Too Many Requests when exceeded.

  ## Options

    * `:max_requests` — maximum requests per window (required)
    * `:window_ms` — window size in milliseconds (default: 60_000)
  """

  import Plug.Conn
  import Phoenix.Controller

  @behaviour Plug

  @table __MODULE__

  @impl true
  def init(opts) do
    %{
      max_requests: Keyword.fetch!(opts, :max_requests),
      window_ms: Keyword.get(opts, :window_ms, 60_000)
    }
  end

  @impl true
  def call(conn, %{max_requests: max, window_ms: window_ms}) do
    ensure_table()

    key = rate_limit_key(conn)
    window_id = div(System.monotonic_time(:millisecond), window_ms)
    ets_key = {key, window_id}

    count =
      :ets.update_counter(@table, ets_key, {2, 1}, {ets_key, 0})

    remaining = max(max - count, 0)

    conn = put_rate_limit_headers(conn, max, remaining)

    if count > max do
      conn
      |> put_status(:too_many_requests)
      |> json(%{error: %{code: "rate_limited", message: "Rate limit exceeded. Try again later."}})
      |> halt()
    else
      conn
    end
  end

  defp rate_limit_key(conn) do
    case conn.assigns[:current_scope] do
      %{user: %{id: user_id}} -> "api:#{user_id}"
      _ -> "api:#{:erlang.phash2(conn.remote_ip)}"
    end
  end

  defp ensure_table do
    case :ets.info(@table) do
      :undefined -> :ets.new(@table, [:set, :public, :named_table])
      _ -> :ok
    end
  end

  defp put_rate_limit_headers(conn, limit, remaining) do
    conn
    |> put_resp_header("x-ratelimit-limit", to_string(limit))
    |> put_resp_header("x-ratelimit-remaining", to_string(remaining))
  end
end
