defmodule Onesqlx.Repo.Migrations.AddScopesToApiTokens do
  use Ecto.Migration

  def change do
    alter table(:api_tokens) do
      add :scopes, {:array, :string}, default: ["read", "execute", "manage"], null: false
    end
  end
end
