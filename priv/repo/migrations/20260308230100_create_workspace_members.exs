defmodule Onesqlx.Repo.Migrations.CreateWorkspaceMembers do
  use Ecto.Migration

  def change do
    create table(:workspace_members, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :role, :string, null: false, default: "member"

      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:workspace_members, [:workspace_id])
    create index(:workspace_members, [:user_id])
    create unique_index(:workspace_members, [:workspace_id, :user_id])
  end
end
