defmodule OnesqlxWeb.MetricsController do
  @moduledoc """
  Exposes Prometheus metrics at `/metrics` for scraping.
  """

  use OnesqlxWeb, :controller

  def index(conn, _params) do
    metrics = TelemetryMetricsPrometheus.Core.scrape(:onesqlx_prometheus)

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, metrics)
  end
end
