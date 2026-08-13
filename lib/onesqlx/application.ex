defmodule Onesqlx.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    warn_if_mailer_unconfigured()

    children = [
      OnesqlxWeb.Telemetry,
      Onesqlx.Repo,
      {DNSCluster, query: Application.get_env(:onesqlx, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Onesqlx.PubSub},
      {Finch, name: Onesqlx.Finch},
      {Oban, Application.fetch_env!(:onesqlx, Oban)},
      Onesqlx.Querying.CancelRegistry,
      {Cachex, name: :query_cache},
      # Endpoint last: on shutdown it stops first, then Oban drains jobs
      OnesqlxWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Onesqlx.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    OnesqlxWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # :mailer_configured is only set (by config/runtime.exs) in prod, so
  # dev and test never warn.
  defp warn_if_mailer_unconfigured do
    if Application.get_env(:onesqlx, :mailer_configured, true) == false do
      require Logger

      Logger.warning(
        "No production mailer configured — outgoing email (magic links, " <>
          "schedule notifications) will NOT be delivered. " <>
          "Set SMTP_HOST/SMTP_USERNAME/SMTP_PASSWORD or RESEND_API_KEY, " <>
          "and MAIL_FROM for the sender address."
      )
    end
  end
end
