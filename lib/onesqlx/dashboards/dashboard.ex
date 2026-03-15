defmodule Onesqlx.Dashboards.Dashboard do
  @moduledoc """
  Schema for dashboards.

  Dashboards group saved queries into a unified view with charts and tables.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "dashboards" do
    field :title, :string
    field :description, :string

    belongs_to :workspace, Onesqlx.Workspaces.Workspace
    belongs_to :user, Onesqlx.Accounts.User
    has_many :cards, Onesqlx.Dashboards.DashboardCard, preload_order: [asc: :position]

    timestamps(type: :utc_datetime)
  end

  @required_fields [:title]
  @optional_fields [:description, :user_id]

  def changeset(dashboard, attrs) do
    dashboard
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:title, min: 1, max: 255)
    |> foreign_key_constraint(:workspace_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:workspace_id, :title], error_key: :title)
  end
end
