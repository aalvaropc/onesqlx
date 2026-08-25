defmodule Onesqlx.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :onesqlx

  alias Onesqlx.Accounts.Scope
  alias Onesqlx.Accounts.User
  alias Onesqlx.Sample
  alias Onesqlx.Workspaces

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def install_sample do
    load_app()

    for repo <- repos() do
      {:ok, result, _} = Ecto.Migrator.with_repo(repo, &install_sample_for_first_user/1)
      IO.puts("sample install: #{inspect(result)}")
    end
  end

  defp install_sample_for_first_user(repo) do
    with %User{} = user <- List.first(repo.all(User)),
         %{} = workspace <- Workspaces.get_workspace_for_scope(user) do
      Sample.install(Scope.for_user(user, workspace))
    else
      _ -> {:error, :no_user_or_workspace}
    end
  end

  def rotate_encryption do
    load_app()

    for repo <- repos() do
      {:ok, result, _} =
        Ecto.Migrator.with_repo(repo, fn _repo ->
          Onesqlx.DataSources.rotate_credential_encryption()
        end)

      IO.puts("rotation result: #{inspect(result)}")
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # Many platforms require SSL when connecting to the database
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
