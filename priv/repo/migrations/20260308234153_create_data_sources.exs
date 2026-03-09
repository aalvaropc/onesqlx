defmodule Onesqlx.Repo.Migrations.CreateDataSources do
  use Ecto.Migration

  def change do
    create table(:data_sources, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all),
        null: false

      add :name, :string, null: false
      add :adapter, :string, null: false, default: "postgresql"
      add :host, :string, null: false
      add :port, :integer, null: false, default: 5432
      add :database_name, :string, null: false
      add :username, :string, null: false
      add :encrypted_password, :binary, null: false
      add :ssl_enabled, :boolean, null: false, default: false
      add :read_only, :boolean, null: false, default: true
      add :status, :string, null: false, default: "pending"

      timestamps(type: :utc_datetime)
    end

    create index(:data_sources, [:workspace_id])
    create unique_index(:data_sources, [:workspace_id, :name])
  end
end
