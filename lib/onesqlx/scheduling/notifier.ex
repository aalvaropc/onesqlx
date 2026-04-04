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

  defp do_deliver(email, schedule_name, run_attrs) do
    subject = "[OneSQLx] #{schedule_name}: #{run_attrs.status}"
    body = build_body(schedule_name, run_attrs)

    email_msg =
      new()
      |> to(email)
      |> from({"OneSQLx", "noreply@onesqlx.dev"})
      |> subject(subject)
      |> text_body(body)

    case Mailer.deliver(email_msg) do
      {:ok, _} -> {:ok, email_msg}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_body(schedule_name, run_attrs) do
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
