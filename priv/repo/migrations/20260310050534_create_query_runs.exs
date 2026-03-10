defmodule Onesqlx.Repo.Migrations.CreateQueryRuns do
  use Ecto.Migration

  def change do
    create table(:query_runs, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :data_source_id, references(:data_sources, type: :binary_id, on_delete: :nilify_all)
      add :sql, :text, null: false
      add :status, :string, null: false
      add :duration_ms, :integer
      add :row_count, :integer
      add :error_message, :text
      add :executed_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:query_runs, [:workspace_id])
    create index(:query_runs, [:user_id])
    create index(:query_runs, [:data_source_id])
    create index(:query_runs, [:executed_at])
    create index(:query_runs, [:workspace_id, :user_id, :executed_at])
  end
end
