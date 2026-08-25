# Script for populating the database with demo data.
# Idempotent — safe to run multiple times.
#
#     mix run priv/repo/seeds.exs

alias Onesqlx.Accounts.Scope
alias Onesqlx.Accounts.User
alias Onesqlx.Repo
alias Onesqlx.Sample
alias Onesqlx.Workspaces
alias Onesqlx.Workspaces.Workspace

# ── Demo User ──────────────────────────────────────────────────────────

demo_email = "demo@onesqlx.local"

user =
  case Repo.get_by(User, email: demo_email) do
    nil ->
      {:ok, u} =
        %User{}
        |> User.email_changeset(%{email: demo_email})
        |> Repo.insert()

      u
      |> User.password_changeset(%{password: "demo1234demo1234"})
      |> User.confirm_changeset()
      |> Repo.update!()

    existing ->
      existing
  end

IO.puts("✓ Demo user: #{user.email} (password: demo1234demo1234)")

# ── Demo Workspace ─────────────────────────────────────────────────────

workspace =
  case Repo.get_by(Workspace, slug: "demo-workspace") do
    nil ->
      {:ok, ws} = Workspaces.create_workspace_with_owner(user, %{name: "Demo Workspace"})
      ws

    existing ->
      existing
  end

IO.puts("✓ Demo workspace: #{workspace.name} (#{workspace.slug})")

# ── Sample data ────────────────────────────────────────────────────────
# Creates the onesqlx_sample schema with a small e-commerce dataset, a
# read-only role to reach it, and a data source, saved queries, and
# dashboard built on top. See Onesqlx.Sample.

scope = Scope.for_user(user, workspace)

case Sample.install(scope) do
  {:ok, :already_installed} ->
    IO.puts("· Sample data already installed")

  {:ok, %{dashboard: dashboard, queries: queries}} ->
    IO.puts("✓ Sample data source, #{map_size(queries)} saved queries")
    IO.puts("✓ Dashboard: #{dashboard.title}")

  {:error, :insufficient_privileges} ->
    IO.puts("! Skipped sample data: the database user cannot create roles (CREATEROLE)")
end

IO.puts("\n🎉 Seeds complete! Sign in at http://localhost:4000 with #{demo_email}")
