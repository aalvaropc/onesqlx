defmodule Onesqlx.Repo.Migrations.CreateScheduledQueries do
  use Ecto.Migration

  def change do
    create table(:scheduled_queries, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      add :saved_query_id,
          references(:saved_queries, type: :binary_id, on_delete: :delete_all),
          null: false

      add :name, :string, null: false
      add :schedule_type, :string, null: false, default: "daily"
      add :cron_expression, :string
      add :enabled, :boolean, null: false, default: true
      add :last_run_at, :utc_datetime
      add :next_run_at, :utc_datetime
      add :notify_email, :string
      add :max_retries, :integer, null: false, default: 3
      timestamps(type: :utc_datetime)
    end

    create index(:scheduled_queries, [:workspace_id])
    create index(:scheduled_queries, [:saved_query_id])
    create index(:scheduled_queries, [:enabled, :next_run_at])
    create unique_index(:scheduled_queries, [:workspace_id, :name])
  end
end
