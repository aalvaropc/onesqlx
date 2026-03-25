defmodule Onesqlx.Scheduling.ScheduledQueryRun do
  @moduledoc """
  Schema for scheduled query execution runs.

  Each run captures the result (or error) of a scheduled query execution,
  including columns, rows (truncated), duration, and notification status.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @valid_statuses ~w(running success error timeout)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "scheduled_query_runs" do
    field :status, :string
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :duration_ms, :integer
    field :row_count, :integer
    field :result_columns, {:array, :string}, default: []
    field :result_rows, :map
    field :error_message, :string
    field :notified, :boolean, default: false

    belongs_to :scheduled_query, Onesqlx.Scheduling.ScheduledQuery

    timestamps(type: :utc_datetime)
  end

  @required_fields [:status, :started_at]
  @optional_fields [
    :completed_at,
    :duration_ms,
    :row_count,
    :result_columns,
    :result_rows,
    :error_message,
    :notified,
    :scheduled_query_id
  ]

  def changeset(run, attrs) do
    run
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, @valid_statuses)
    |> foreign_key_constraint(:scheduled_query_id)
  end
end
