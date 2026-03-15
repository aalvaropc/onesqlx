defmodule Onesqlx.Repo.Migrations.CreateDashboardCards do
  use Ecto.Migration

  def change do
    create table(:dashboard_cards, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :dashboard_id, references(:dashboards, type: :binary_id, on_delete: :delete_all),
        null: false

      add :saved_query_id, references(:saved_queries, type: :binary_id, on_delete: :nilify_all)
      add :title, :string
      add :type, :string, null: false, default: "table"
      add :position, :integer, null: false, default: 0
      add :config, :map, null: false, default: %{}
      timestamps(type: :utc_datetime)
    end

    create index(:dashboard_cards, [:dashboard_id])
    create index(:dashboard_cards, [:saved_query_id])
  end
end
