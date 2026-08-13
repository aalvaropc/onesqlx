defmodule OnesqlxWeb.Plugs.MetricsAuth do
  @moduledoc """
  Protects the Prometheus `/metrics` endpoint.

  Behavior is driven by the `:metrics_auth` application env, set by
  `config/runtime.exs` in production:

    * `:open` — no auth; the default outside production
    * `:disabled` — endpoint hidden, responds 404; the production default
      when `METRICS_TOKEN` is not set (secure by default)
    * `{:token, token}` — requires `Authorization: Bearer <token>`,
      compared in constant time; matches Prometheus' native
      `authorization.credentials` scrape option
  """

  @behaviour Plug

  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    case Application.get_env(:onesqlx, :metrics_auth, :open) do
      :open -> conn
      :disabled -> halt_with(conn, 404, "Not Found")
      {:token, token} -> verify_bearer(conn, token)
    end
  end

  defp verify_bearer(conn, token) do
    with ["Bearer " <> presented] <- get_req_header(conn, "authorization"),
         true <- Plug.Crypto.secure_compare(presented, token) do
      conn
    else
      _ -> halt_with(conn, 401, "Unauthorized")
    end
  end

  defp halt_with(conn, status, body) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(status, body)
    |> halt()
  end
end
