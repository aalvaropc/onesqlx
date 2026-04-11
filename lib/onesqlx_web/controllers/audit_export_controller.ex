defmodule OnesqlxWeb.AuditExportController do
  @moduledoc """
  Controller for exporting audit events as CSV.
  """

  use OnesqlxWeb, :controller

  alias Onesqlx.Audit
  alias Onesqlx.Export.Csv

  def export(conn, params) do
    scope = conn.assigns.current_scope
    opts = build_filter_opts(params)
    events = Audit.list_all_events(scope, opts)

    rows =
      Enum.map(events, fn e ->
        [
          DateTime.to_string(e.occurred_at),
          (e.user && e.user.email) || "system",
          e.event_type,
          e.resource_type || "",
          e.resource_id || "",
          if(e.metadata && e.metadata != %{}, do: Jason.encode!(e.metadata), else: "")
        ]
      end)

    result = %{
      columns: ["timestamp", "user", "event_type", "resource_type", "resource_id", "metadata"],
      rows: rows
    }

    filename = Csv.filename("audit_log")

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, IO.iodata_to_binary(Csv.encode(result)))
  end

  defp build_filter_opts(params) do
    opts = []

    opts =
      if params["event_type"] != "", do: [{:event_type, params["event_type"]} | opts], else: opts

    if params["since"] && params["since"] != "" do
      case Date.from_iso8601(params["since"]) do
        {:ok, date} -> [{:since, DateTime.new!(date, ~T[00:00:00], "Etc/UTC")} | opts]
        _ -> opts
      end
    else
      opts
    end
  end
end
