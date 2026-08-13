defmodule Onesqlx.Scheduling.Notifier do
  @moduledoc """
  Delivers email and webhook notifications for scheduled query run results.
  """

  require Logger

  import Swoosh.Email

  alias Onesqlx.Mailer

  @doc """
  Sends an email with the run result if `notify_email` is configured.
  No-ops if `notify_email` is nil or empty.
  """
  @spec deliver_run_result(map(), map()) :: {:ok, Swoosh.Email.t()} | :ok
  def deliver_run_result(scheduled_query, run_attrs) do
    case scheduled_query.notify_email do
      nil -> :ok
      "" -> :ok
      email -> do_deliver(email, scheduled_query.name, run_attrs)
    end
  end

  @doc """
  Posts run result as JSON to the webhook URL if configured.
  No-ops if `webhook_url` is nil or empty. Errors are logged but never raised.
  """
  @spec deliver_webhook(map(), map()) :: :ok | {:ok, term()} | {:error, term()}
  def deliver_webhook(scheduled_query, run_attrs) do
    case Map.get(scheduled_query, :webhook_url) do
      nil -> :ok
      "" -> :ok
      url -> do_deliver_webhook(url, scheduled_query.name, run_attrs)
    end
  end

  @max_email_rows 20

  defp do_deliver(email, schedule_name, run_attrs) do
    subject = "[OneSQLx] #{schedule_name}: #{run_attrs.status}"
    text = build_text_body(schedule_name, run_attrs)
    html = build_html_body(schedule_name, run_attrs)

    email_msg =
      new()
      |> to(email)
      |> from(Onesqlx.MailerConfig.sender())
      |> subject(subject)
      |> text_body(text)
      |> html_body(html)

    case Mailer.deliver(email_msg) do
      {:ok, _} -> {:ok, email_msg}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_text_body(schedule_name, run_attrs) do
    status_line = "Status: #{run_attrs.status}"

    details =
      [
        if(run_attrs[:duration_ms], do: "Duration: #{run_attrs.duration_ms}ms"),
        if(run_attrs[:row_count], do: "Rows: #{run_attrs.row_count}"),
        if(run_attrs[:error_message], do: "Error: #{run_attrs.error_message}")
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")

    """
    Scheduled Query: #{schedule_name}
    #{status_line}
    #{details}

    --
    OneSQLx
    """
  end

  defp build_html_body(schedule_name, run_attrs) do
    status_color = status_to_color(run_attrs.status)
    result_table = build_result_table(run_attrs)

    """
    <!DOCTYPE html>
    <html>
    <head><meta charset="utf-8"></head>
    <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 0; padding: 20px; background: #f5f5f5;">
      <div style="max-width: 700px; margin: 0 auto; background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
        <div style="padding: 20px 24px; border-bottom: 1px solid #e5e5e5;">
          <h2 style="margin: 0 0 8px; font-size: 18px;">#{escape(schedule_name)}</h2>
          <span style="display: inline-block; padding: 2px 10px; border-radius: 12px; font-size: 13px; font-weight: 600; color: white; background: #{status_color};">#{run_attrs.status}</span>
        </div>
        <div style="padding: 16px 24px;">
          #{build_details_html(run_attrs)}
          #{result_table}
        </div>
        <div style="padding: 12px 24px; border-top: 1px solid #e5e5e5; color: #999; font-size: 12px;">
          OneSQLx
        </div>
      </div>
    </body>
    </html>
    """
  end

  defp build_details_html(run_attrs) do
    items =
      [
        if(run_attrs[:duration_ms], do: {"Duration", "#{run_attrs.duration_ms}ms"}),
        if(run_attrs[:row_count], do: {"Rows", "#{run_attrs.row_count}"}),
        if(run_attrs[:error_message], do: {"Error", run_attrs.error_message})
      ]
      |> Enum.reject(&is_nil/1)

    if items == [] do
      ""
    else
      rows =
        Enum.map_join(items, fn {label, value} ->
          "<tr><td style=\"padding: 4px 12px 4px 0; color: #666; font-size: 13px;\">#{label}</td><td style=\"padding: 4px 0; font-size: 13px;\">#{escape(value)}</td></tr>"
        end)

      "<table style=\"margin-bottom: 16px;\">#{rows}</table>"
    end
  end

  defp build_result_table(run_attrs) do
    columns = run_attrs[:result_columns] || []
    all_rows = get_in(run_attrs, [:result_rows, "rows"]) || []
    rows = Enum.take(all_rows, @max_email_rows)

    if columns == [] || rows == [] do
      ""
    else
      header_cells =
        Enum.map_join(columns, fn col ->
          "<th style=\"padding: 6px 10px; text-align: left; background: #f8f8f8; border: 1px solid #e5e5e5; font-size: 12px;\">#{escape(col)}</th>"
        end)

      body_rows = Enum.map_join(rows, &render_row/1)

      truncation_note =
        if length(all_rows) > @max_email_rows do
          "<p style=\"color: #999; font-size: 12px; margin-top: 8px;\">Showing #{@max_email_rows} of #{length(all_rows)} rows</p>"
        else
          ""
        end

      """
      <h3 style="font-size: 14px; margin: 16px 0 8px;">Results</h3>
      <div style="overflow-x: auto;">
        <table style="border-collapse: collapse; width: 100%;">
          <thead><tr>#{header_cells}</tr></thead>
          <tbody>#{body_rows}</tbody>
        </table>
      </div>
      #{truncation_note}
      """
    end
  end

  defp render_row(row) do
    cells =
      Enum.map_join(row, fn cell ->
        "<td style=\"padding: 4px 10px; border: 1px solid #e5e5e5; font-size: 12px; font-family: monospace;\">#{escape(to_string(cell))}</td>"
      end)

    "<tr>#{cells}</tr>"
  end

  defp status_to_color("success"), do: "#22c55e"
  defp status_to_color("error"), do: "#ef4444"
  defp status_to_color("timeout"), do: "#f59e0b"
  defp status_to_color(_), do: "#6b7280"

  defp escape(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp escape(other), do: escape(to_string(other))

  defp do_deliver_webhook(url, schedule_name, run_attrs) do
    payload = %{
      text: "[OneSQLx] #{schedule_name}: #{run_attrs.status}",
      schedule_name: schedule_name,
      status: run_attrs.status,
      duration_ms: run_attrs[:duration_ms],
      row_count: run_attrs[:row_count],
      error_message: run_attrs[:error_message]
    }

    case Req.post(url, json: payload, receive_timeout: 10_000) do
      {:ok, %{status: status}} when status in 200..299 ->
        {:ok, :delivered}

      {:ok, %{status: status}} ->
        Logger.warning("Webhook delivery failed for #{schedule_name}: HTTP #{status}")
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        Logger.warning("Webhook delivery failed for #{schedule_name}: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    e ->
      Logger.warning("Webhook delivery crashed for #{schedule_name}: #{Exception.message(e)}")
      {:error, e}
  end
end
