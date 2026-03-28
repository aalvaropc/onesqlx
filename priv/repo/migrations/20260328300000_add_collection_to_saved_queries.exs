defmodule Onesqlx.Repo.Migrations.AddCollectionToSavedQueries do
  use Ecto.Migration

  def change do
    alter table(:saved_queries) do
      add :collection, :string
    end

    create index(:saved_queries, [:workspace_id, :collection])
  end
end
