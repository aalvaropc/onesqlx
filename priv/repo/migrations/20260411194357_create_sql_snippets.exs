defmodule Onesqlx.Repo.Migrations.CreateSqlSnippets do
  use Ecto.Migration

  def change do
    create table(:sql_snippets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :sql, :text, null: false
      add :description, :string

      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:sql_snippets, [:workspace_id])
    create unique_index(:sql_snippets, [:workspace_id, :title])
  end
end
