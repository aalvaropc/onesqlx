# Script for populating the database with demo data.
# Idempotent — safe to run multiple times.
#
#     mix run priv/repo/seeds.exs

alias Onesqlx.Repo
alias Onesqlx.Accounts.User
alias Onesqlx.Workspaces
alias Onesqlx.Workspaces.Workspace
alias Onesqlx.Workspaces.WorkspaceMember
alias Onesqlx.DataSources.DataSource
alias Onesqlx.DataSources.Encryption
alias Onesqlx.SavedQueries.SavedQuery

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

IO.puts("✓ Demo user: #{user.email}")

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

# ── Demo Data Source (points to db_external container) ─────────────────

external_host = System.get_env("EXTERNAL_DB_HOST", "localhost")
external_port = String.to_integer(System.get_env("EXTERNAL_DB_PORT", "5433"))

data_source =
  case Repo.get_by(DataSource, workspace_id: workspace.id, name: "External Demo DB") do
    nil ->
      %DataSource{workspace_id: workspace.id}
      |> DataSource.changeset(%{
        name: "External Demo DB",
        host: external_host,
        port: external_port,
        database_name: "external_test",
        username: "postgres",
        password: "postgres",
        ssl_enabled: false,
        status: "pending"
      })
      |> Repo.insert!()

    existing ->
      existing
  end

IO.puts("✓ Demo data source: #{data_source.name} (#{data_source.host}:#{data_source.port})")

# ── Demo Saved Queries ─────────────────────────────────────────────────

demo_queries = [
  %{
    title: "List all tables",
    description: "Shows all user-created tables in the public schema",
    sql: """
    SELECT table_name, table_type
    FROM information_schema.tables
    WHERE table_schema = 'public'
    ORDER BY table_name;
    """,
    tags: ["catalog", "schema"],
    is_favorite: true
  },
  %{
    title: "Table sizes",
    description: "Shows disk usage for each table, ordered by size",
    sql: """
    SELECT
      relname AS table_name,
      pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size,
      pg_size_pretty(pg_relation_size(c.oid)) AS data_size,
      pg_size_pretty(pg_indexes_size(c.oid)) AS index_size
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind = 'r'
    ORDER BY pg_total_relation_size(c.oid) DESC;
    """,
    tags: ["monitoring", "disk"],
    is_favorite: false
  },
  %{
    title: "Active connections",
    description: "Lists active connections to the database",
    sql: """
    SELECT
      pid,
      usename,
      application_name,
      client_addr,
      state,
      query_start,
      now() - query_start AS duration
    FROM pg_stat_activity
    WHERE state IS NOT NULL
    ORDER BY query_start DESC NULLS LAST;
    """,
    tags: ["monitoring", "connections"],
    is_favorite: true
  }
]

for query_attrs <- demo_queries do
  case Repo.get_by(SavedQuery, workspace_id: workspace.id, title: query_attrs.title) do
    nil ->
      %SavedQuery{workspace_id: workspace.id, user_id: user.id, data_source_id: data_source.id}
      |> SavedQuery.changeset(query_attrs)
      |> Repo.insert!()

      IO.puts("  ✓ Saved query: #{query_attrs.title}")

    _existing ->
      IO.puts("  · Saved query already exists: #{query_attrs.title}")
  end
end

IO.puts("\n🎉 Seeds complete!")
