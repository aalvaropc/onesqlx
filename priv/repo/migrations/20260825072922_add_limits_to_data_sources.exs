defmodule Onesqlx.Repo.Migrations.AddLimitsToDataSources do
  use Ecto.Migration

  def change do
    alter table(:data_sources) do
      # Matches the previously hardcoded 30s statement timeout
      add :statement_timeout_ms, :integer, null: false, default: 30_000
      # nil = no cap (previous behavior)
      add :max_row_limit, :integer
    end
  end
end
