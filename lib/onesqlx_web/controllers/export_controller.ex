defmodule OnesqlxWeb.ExportController do
  @moduledoc """
  Controller for exporting query results as CSV, JSON, or Excel files.
  """

  use OnesqlxWeb, :controller

  alias Onesqlx.DataSources
  alias Onesqlx.Export.Csv
  alias Onesqlx.Querying.Executor
  alias Onesqlx.Querying.Params

  def csv(conn, %{"data_source_id" => ds_id, "sql" => sql, "label" => label} = params) do
    with_result(conn, ds_id, sql, query_params(params), fn result ->
      filename = Csv.filename(label)

      conn =
        conn
        |> put_resp_content_type("text/csv")
        |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
        |> send_chunked(200)

      {:ok, conn} = chunk(conn, [Csv.encode_row(result.columns), "\r\n"])
      stream_rows(conn, result.rows)
    end)
  end

  def json(conn, %{"data_source_id" => ds_id, "sql" => sql, "label" => label} = params) do
    with_result(conn, ds_id, sql, query_params(params), fn result ->
      filename = export_filename(label, "json")

      data =
        Enum.map(result.rows, fn row ->
          Enum.zip(result.columns, row) |> Map.new()
        end)

      conn
      |> put_resp_content_type("application/json")
      |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
      |> send_resp(200, Jason.encode!(data))
    end)
  end

  def xlsx(conn, %{"data_source_id" => ds_id, "sql" => sql, "label" => label} = params) do
    with_result(conn, ds_id, sql, query_params(params), fn result ->
      filename = export_filename(label, "xlsx")
      header = Enum.map(result.columns, &to_string/1)
      rows = Enum.map(result.rows, fn row -> Enum.map(row, &xlsx_cell/1) end)

      sheet = %Elixlsx.Sheet{name: "Results", rows: [header | rows]}
      workbook = %Elixlsx.Workbook{sheets: [sheet]}
      {:ok, {_, binary}} = Elixlsx.write_to_memory(workbook, filename)

      conn
      |> put_resp_content_type(
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      )
      |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
      |> send_resp(200, binary)
    end)
  end

  defp with_result(conn, ds_id, sql, params, success_fn) do
    scope = conn.assigns.current_scope
    data_source = DataSources.get_data_source!(scope, ds_id)

    # Params.substitute/2 raises on missing values, so check up front and
    # fail with a flash instead of a 500.
    case Params.extract(sql) -- Map.keys(params) do
      [] ->
        execute_and_respond(conn, data_source, sql, params, success_fn)

      missing ->
        conn
        |> put_flash(
          :error,
          "Export failed: missing parameter values: #{Enum.join(missing, ", ")}"
        )
        |> redirect(to: ~p"/sql-editor")
    end
  end

  defp execute_and_respond(conn, data_source, sql, params, success_fn) do
    case Executor.execute(data_source, sql, row_limit: 10_000, params: params) do
      {:ok, result} ->
        success_fn.(result)

      {:error, _type, message} ->
        conn
        |> put_flash(:error, "Export failed: #{message}")
        |> redirect(to: ~p"/sql-editor")
    end
  end

  defp query_params(%{"params" => params}) when is_map(params) do
    for {name, value} <- params, is_binary(name), is_binary(value), into: %{}, do: {name, value}
  end

  defp query_params(_), do: %{}

  defp stream_rows(conn, rows) do
    Enum.reduce_while(rows, conn, fn row, conn ->
      case chunk(conn, [Csv.encode_row(row), "\r\n"]) do
        {:ok, conn} -> {:cont, conn}
        {:error, :closed} -> {:halt, conn}
      end
    end)
  end

  defp export_filename(label, ext) do
    timestamp = Calendar.strftime(DateTime.utc_now(), "%Y%m%d_%H%M%S")
    safe_label = label |> String.replace(~r/[^a-zA-Z0-9_-]/, "_") |> String.slice(0, 50)
    "#{safe_label}_#{timestamp}.#{ext}"
  end

  defp xlsx_cell(nil), do: ""
  defp xlsx_cell(true), do: "true"
  defp xlsx_cell(false), do: "false"
  defp xlsx_cell(%Decimal{} = d), do: Decimal.to_float(d)
  defp xlsx_cell(v) when is_number(v), do: v
  defp xlsx_cell(v), do: to_string(v)
end
