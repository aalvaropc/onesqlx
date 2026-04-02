defmodule OnesqlxWeb.ExportController do
  @moduledoc """
  Controller for exporting query results as CSV files.
  """

  use OnesqlxWeb, :controller

  alias Onesqlx.DataSources
  alias Onesqlx.Export.Csv
  alias Onesqlx.Querying.Executor

  def csv(conn, %{"data_source_id" => ds_id, "sql" => sql, "label" => label}) do
    scope = conn.assigns.current_scope
    data_source = DataSources.get_data_source!(scope, ds_id)

    case Executor.execute(data_source, sql, row_limit: 10_000) do
      {:ok, result} ->
        filename = Csv.filename(label)

        conn =
          conn
          |> put_resp_content_type("text/csv")
          |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
          |> send_chunked(200)

        {:ok, conn} = chunk(conn, [Csv.encode_row(result.columns), "\r\n"])
        stream_rows(conn, result.rows)

      {:error, _type, message} ->
        conn
        |> put_flash(:error, "Export failed: #{message}")
        |> redirect(to: ~p"/sql-editor")
    end
  end

  defp stream_rows(conn, rows) do
    Enum.reduce_while(rows, conn, fn row, conn ->
      case chunk(conn, [Csv.encode_row(row), "\r\n"]) do
        {:ok, conn} -> {:cont, conn}
        {:error, :closed} -> {:halt, conn}
      end
    end)
  end
end
