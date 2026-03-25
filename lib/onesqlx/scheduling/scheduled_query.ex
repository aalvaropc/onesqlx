defmodule Onesqlx.Scheduling.ScheduledQuery do
  @moduledoc """
  Schema for scheduled queries.

  A scheduled query ties a saved query to a recurring execution schedule.
  Supports hourly, daily, weekly, or custom cron expressions.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Onesqlx.Scheduling.CronParser

  @valid_schedule_types ~w(hourly daily weekly cron)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "scheduled_queries" do
    field :name, :string
    field :schedule_type, :string, default: "daily"
    field :cron_expression, :string
    field :enabled, :boolean, default: true
    field :last_run_at, :utc_datetime
    field :next_run_at, :utc_datetime
    field :notify_email, :string
    field :max_retries, :integer, default: 3

    belongs_to :workspace, Onesqlx.Workspaces.Workspace
    belongs_to :user, Onesqlx.Accounts.User
    belongs_to :saved_query, Onesqlx.SavedQueries.SavedQuery
    has_many :runs, Onesqlx.Scheduling.ScheduledQueryRun

    timestamps(type: :utc_datetime)
  end

  @required_fields [:name, :schedule_type, :saved_query_id]
  @optional_fields [
    :cron_expression,
    :enabled,
    :next_run_at,
    :last_run_at,
    :notify_email,
    :max_retries,
    :user_id
  ]

  def changeset(scheduled_query, attrs) do
    scheduled_query
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 1, max: 255)
    |> validate_inclusion(:schedule_type, @valid_schedule_types)
    |> validate_cron_expression()
    |> validate_email_format()
    |> validate_number(:max_retries, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
    |> foreign_key_constraint(:workspace_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:saved_query_id)
    |> unique_constraint([:workspace_id, :name], error_key: :name)
  end

  defp validate_cron_expression(changeset) do
    schedule_type = get_field(changeset, :schedule_type)
    cron = get_field(changeset, :cron_expression)

    cond do
      schedule_type == "cron" && (is_nil(cron) || cron == "") ->
        add_error(changeset, :cron_expression, "is required for cron schedule type")

      schedule_type == "cron" && !valid_cron_format?(cron) ->
        add_error(changeset, :cron_expression, "is not a valid cron expression")

      true ->
        changeset
    end
  end

  defp valid_cron_format?(expression) when is_binary(expression) do
    CronParser.valid?(expression)
  end

  defp valid_cron_format?(_), do: false

  defp validate_email_format(changeset) do
    case get_field(changeset, :notify_email) do
      nil -> changeset
      "" -> changeset
      _email -> validate_format(changeset, :notify_email, ~r/^[^\s]+@[^\s]+$/)
    end
  end
end
