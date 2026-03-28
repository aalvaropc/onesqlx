defmodule Onesqlx.Repo.Migrations.CreateAuditEvents do
  use Ecto.Migration

  def change do
    create table(:audit_events, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :event_type, :string, null: false
      add :resource_type, :string
      add :resource_id, :binary_id
      add :metadata, :map, null: false, default: %{}
      add :occurred_at, :utc_datetime, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:audit_events, [:workspace_id, :occurred_at])
    create index(:audit_events, [:workspace_id, :event_type])
    create index(:audit_events, [:user_id])
  end
end
