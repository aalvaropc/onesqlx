defmodule Onesqlx.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      OnesqlxWeb.Telemetry,
      Onesqlx.Repo,
      {DNSCluster, query: Application.get_env(:onesqlx, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Onesqlx.PubSub},
      # Start a worker by calling: Onesqlx.Worker.start_link(arg)
      # {Onesqlx.Worker, arg},
      # Start to serve requests, typically the last entry
      OnesqlxWeb.Endpoint,
      {Finch, name: Onesqlx.Finch},
      {Oban, Application.fetch_env!(:onesqlx, Oban)},

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
end
