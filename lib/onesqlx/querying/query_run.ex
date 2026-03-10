defmodule Onesqlx.Querying.QueryRun do
  @moduledoc """
  Schema for recording SQL query execution history.

  Stores metadata about each query run including the SQL text, execution status,
  duration, row count, and any error messages. Used for audit and history purposes.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "query_runs" do
    field :sql, :string
    field :status, :string
    field :duration_ms, :integer
    field :row_count, :integer
    field :error_message, :string
    field :executed_at, :utc_datetime

    belongs_to :workspace, Onesqlx.Workspaces.Workspace
    belongs_to :user, Onesqlx.Accounts.User
    belongs_to :data_source, Onesqlx.DataSources.DataSource

    timestamps(type: :utc_datetime)
  end

  @valid_statuses ~w(success error timeout blocked)

  @required_fields [:sql, :status, :executed_at, :workspace_id]
  @optional_fields [:user_id, :data_source_id, :duration_ms, :row_count, :error_message]

  def changeset(query_run, attrs) do
    query_run
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, @valid_statuses)
    |> foreign_key_constraint(:workspace_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:data_source_id)
  end
end
