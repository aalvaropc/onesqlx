defmodule Mix.Tasks.Onesqlx.Sample do
  @shortdoc "Installs the sample data source, queries, and dashboard"

  @moduledoc """
  Installs a self-contained sample dataset so a fresh instance has
  something to explore without connecting a database first.

      mix onesqlx.sample [--email user@example.com]

  Without `--email`, the sample is installed for the first user in the
  instance. In a release, use
  `bin/onesqlx eval 'Onesqlx.Release.install_sample()'`.

  The dataset lives in an `onesqlx_sample` schema inside OneSQLx's own
  database and is read through a dedicated PostgreSQL role that can only
  select from that schema. Requires a database user with CREATEROLE.
  """

  use Mix.Task

  alias Onesqlx.Accounts
  alias Onesqlx.Accounts.Scope
  alias Onesqlx.Sample
  alias Onesqlx.Workspaces

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(args, strict: [email: :string])

    case resolve_scope(opts[:email]) do
      {:ok, scope} -> install(scope)
      {:error, message} -> Mix.raise(message)
    end
  end

  defp resolve_scope(nil) do
    case Onesqlx.Repo.all(Accounts.User) do
      [] -> {:error, "No users found. Register one first, or pass --email."}
      [user | _] -> scope_for(user)
    end
  end

  defp resolve_scope(email) do
    case Accounts.get_user_by_email(email) do
      nil -> {:error, "No user found with email #{email}."}
      user -> scope_for(user)
    end
  end

  defp scope_for(user) do
    case Workspaces.get_workspace_for_scope(user) do
      nil -> {:error, "User #{user.email} has no workspace."}
      workspace -> {:ok, Scope.for_user(user, workspace)}
    end
  end

  defp install(scope) do
    case Sample.install(scope) do
      {:ok, :already_installed} ->
        Mix.shell().info("Sample data is already installed in this workspace.")

      {:ok, %{dashboard: dashboard}} ->
        Mix.shell().info("""
        Sample data installed.

          Dashboard: #{dashboard.title}
          Workspace: #{scope.workspace.name}

        The catalog is syncing in the background; autocomplete will pick
        up the sample tables shortly.
        """)

      {:error, :insufficient_privileges} ->
        Mix.raise(
          "The database user cannot create roles (CREATEROLE), which the sample data needs."
        )
    end
  end
end
