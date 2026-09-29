defmodule Onesqlx.Repo.Migrations.CreateWorkspaceInvitations do
  use Ecto.Migration

  def change do
    create table(:workspace_invitations, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all),
        null: false

      add :invited_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :email, :citext, null: false
      add :role, :string, null: false, default: "member"
      add :token_hash, :binary, null: false
      add :expires_at, :utc_datetime, null: false
      add :accepted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:workspace_invitations, [:token_hash])
    create index(:workspace_invitations, [:workspace_id])

    # One pending invitation per email per workspace
    create unique_index(:workspace_invitations, [:workspace_id, :email],
             where: "accepted_at IS NULL",
             name: :workspace_invitations_pending_unique
           )
  end
end
