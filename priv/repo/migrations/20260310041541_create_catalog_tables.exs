defmodule Onesqlx.Repo.Migrations.CreateCatalogTables do
  use Ecto.Migration

  def change do
    create table(:catalog_schemas, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :data_source_id, references(:data_sources, type: :binary_id, on_delete: :delete_all),
        null: false

      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:catalog_schemas, [:data_source_id])
    create unique_index(:catalog_schemas, [:data_source_id, :name])

    create table(:catalog_tables, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :catalog_schema_id,
          references(:catalog_schemas, type: :binary_id, on_delete: :delete_all),
          null: false

      add :data_source_id, references(:data_sources, type: :binary_id, on_delete: :delete_all),
        null: false

      add :name, :string, null: false
      add :table_type, :string, null: false, default: "BASE TABLE"
      add :estimated_row_count, :bigint

      timestamps(type: :utc_datetime)
    end

    create index(:catalog_tables, [:catalog_schema_id])
    create index(:catalog_tables, [:data_source_id])
    create unique_index(:catalog_tables, [:catalog_schema_id, :name])

    create table(:catalog_columns, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :catalog_table_id,
          references(:catalog_tables, type: :binary_id, on_delete: :delete_all),
          null: false

      add :data_source_id, references(:data_sources, type: :binary_id, on_delete: :delete_all),
        null: false

      add :name, :string, null: false
      add :data_type, :string, null: false
      add :ordinal_position, :integer, null: false
      add :is_nullable, :boolean, null: false, default: true
      add :column_default, :text
      add :is_primary_key, :boolean, null: false, default: false
      add :character_maximum_length, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:catalog_columns, [:catalog_table_id])
    create index(:catalog_columns, [:data_source_id])
    create unique_index(:catalog_columns, [:catalog_table_id, :name])
  end
end
