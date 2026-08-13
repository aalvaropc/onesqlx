defmodule Onesqlx.MailerConfig do
  @moduledoc """
  Resolves the production mailer adapter and the sender address from
  environment variables.

  Adapter selection order (first match wins):

    1. `SMTP_HOST` set → `Swoosh.Adapters.SMTP` — works with any provider
       (`SMTP_PORT` defaults to 587, `SMTP_USERNAME`/`SMTP_PASSWORD` enable
       auth, `SMTP_TLS=false` disables STARTTLS for local relays)
    2. `RESEND_API_KEY` set → `Swoosh.Adapters.Resend`
    3. neither → `:local` — emails stay in the in-memory mailbox and are
       never delivered; the application logs a warning at startup in prod

  `config/runtime.exs` calls `resolve/1` at boot. The function is pure so
  every combination can be unit tested.
  """

  @default_sender {"OneSQLx", "noreply@localhost"}

  @doc """
  Returns `{adapter, opts}` for the mailer, or `:local` when no provider
  is configured. `env` is a map like the one from `System.get_env/0`.
  """
  def resolve(env) when is_map(env) do
    cond do
      present?(env["SMTP_HOST"]) -> {Swoosh.Adapters.SMTP, smtp_opts(env)}
      present?(env["RESEND_API_KEY"]) -> {Swoosh.Adapters.Resend, api_key: env["RESEND_API_KEY"]}
      true -> :local
    end
  end

  @doc """
  The `{name, email}` sender for all outgoing email, configurable with
  `MAIL_FROM` / `MAIL_FROM_NAME` (wired in `config/runtime.exs`).
  """
  def sender do
    Application.get_env(:onesqlx, :mail_from, @default_sender)
  end

  defp smtp_opts(env) do
    username = env["SMTP_USERNAME"]

    [
      relay: env["SMTP_HOST"],
      port: String.to_integer(env["SMTP_PORT"] || "587"),
      username: username,
      password: env["SMTP_PASSWORD"],
      auth: if(present?(username), do: :always, else: :never),
      tls: if(env["SMTP_TLS"] == "false", do: :never, else: :always),
      retries: 2
    ]
  end

  defp present?(value), do: value not in [nil, ""]
end
