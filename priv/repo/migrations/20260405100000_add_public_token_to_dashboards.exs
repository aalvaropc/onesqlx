defmodule Onesqlx.Repo.Migrations.AddPublicTokenToDashboards do
  use Ecto.Migration

  def change do
    alter table(:dashboards) do
      add :public_token, :binary_id
    end

    create unique_index(:dashboards, [:public_token],
             where: "public_token IS NOT NULL",
             name: :dashboards_public_token_unique_index
           )
  end
end
