defmodule Onesqlx.Repo.Migrations.AddTrigramSearchIndexes do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm", ""

    # Trigram GIN indexes make ILIKE '%term%' an index scan instead of a
    # sequential scan over every row in the workspace.
    create index(:saved_queries, ["title gin_trgm_ops"],
             using: :gin,
             name: :saved_queries_title_trgm_idx
           )

    create index(:saved_queries, ["sql gin_trgm_ops"],
             using: :gin,
             name: :saved_queries_sql_trgm_idx
           )

    create index(:dashboards, ["title gin_trgm_ops"],
             using: :gin,
             name: :dashboards_title_trgm_idx
           )

    create index(:scheduled_queries, ["name gin_trgm_ops"],
             using: :gin,
             name: :scheduled_queries_name_trgm_idx
           )

    create index(:data_sources, ["name gin_trgm_ops"],
             using: :gin,
             name: :data_sources_name_trgm_idx
           )
  end
end
