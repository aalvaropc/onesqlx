defmodule Onesqlx.Repo.Migrations.AddWebhookUrlToScheduledQueries do
  use Ecto.Migration

  def change do
    alter table(:scheduled_queries) do
      add :webhook_url, :string
    end
  end
end
