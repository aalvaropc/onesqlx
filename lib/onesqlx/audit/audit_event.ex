defmodule Onesqlx.Audit.AuditEvent do
  @moduledoc """
  Schema for audit events.

  Records significant system events for accountability and usage analysis.
  Events are immutable — they are inserted but never updated or deleted
  by application code.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "audit_events" do
    field :event_type, :string
    field :resource_type, :string
    field :resource_id, :binary_id
    field :metadata, :map, default: %{}
    field :occurred_at, :utc_datetime

    belongs_to :workspace, Onesqlx.Workspaces.Workspace
    belongs_to :user, Onesqlx.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @required_fields [:event_type, :occurred_at]
  @optional_fields [:resource_type, :resource_id, :metadata, :user_id, :workspace_id]

  def changeset(event, attrs) do
    event
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:workspace_id)
    |> foreign_key_constraint(:user_id)
  end
end
