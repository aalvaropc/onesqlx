defmodule Onesqlx.Repo.Migrations.AddAlertFieldsToScheduledQueries do
  use Ecto.Migration

  def change do
    alter table(:scheduled_queries) do
      add :alert_condition, :string
      add :alert_threshold, :decimal
    end
  end
end
