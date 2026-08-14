defmodule Onesqlx.Repo.Migrations.AddVariablesToDashboards do
  use Ecto.Migration

  def change do
    alter table(:dashboards) do
      add :variables, {:array, :map}, null: false, default: []
    end
  end
end
