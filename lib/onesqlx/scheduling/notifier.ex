defmodule Onesqlx.Scheduling.Notifier do
  @moduledoc """
  Delivers email notifications for scheduled query run results.
  """

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
end
