defmodule Onesqlx.Repo.Migrations.CreateDashboards do
  use Ecto.Migration

  def change do
    create table(:dashboards, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :title, :string, null: false
      add :description, :text
      timestamps(type: :utc_datetime)
    end

    create index(:dashboards, [:workspace_id])
    create index(:dashboards, [:user_id])
    create unique_index(:dashboards, [:workspace_id, :title])
  end
end
