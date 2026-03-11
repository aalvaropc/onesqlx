defmodule Onesqlx.Repo.Migrations.CreateSavedQueries do
  use Ecto.Migration

  def change do
    create table(:saved_queries, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :data_source_id, references(:data_sources, type: :binary_id, on_delete: :nilify_all)
      add :title, :string, null: false
      add :description, :text
      add :sql, :text, null: false
      add :tags, {:array, :string}, null: false, default: []
      add :is_favorite, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:saved_queries, [:workspace_id])
    create index(:saved_queries, [:user_id])
    create index(:saved_queries, [:data_source_id])
    create unique_index(:saved_queries, [:workspace_id, :title])
  end
end
