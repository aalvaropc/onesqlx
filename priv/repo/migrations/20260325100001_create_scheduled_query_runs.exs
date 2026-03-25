defmodule Onesqlx.Repo.Migrations.CreateScheduledQueryRuns do
  use Ecto.Migration

  def change do
    create table(:scheduled_query_runs, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :scheduled_query_id,
          references(:scheduled_queries, type: :binary_id, on_delete: :delete_all),
          null: false

      add :status, :string, null: false
      add :started_at, :utc_datetime, null: false
      add :completed_at, :utc_datetime
      add :duration_ms, :integer
      add :row_count, :integer
      add :result_columns, {:array, :string}, default: []
      add :result_rows, :map
      add :error_message, :text
      add :notified, :boolean, null: false, default: false
      timestamps(type: :utc_datetime)
    end

    create index(:scheduled_query_runs, [:scheduled_query_id])
    create index(:scheduled_query_runs, [:status])
  end
end
