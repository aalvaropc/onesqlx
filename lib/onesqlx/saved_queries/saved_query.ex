defmodule Onesqlx.SavedQueries.SavedQuery do
  @moduledoc """
  Schema for persisted SQL queries.

  Saved queries allow users to store, organize, and quickly reuse useful SQL
  statements within their workspace.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "saved_queries" do
    field :title, :string
    field :description, :string
    field :sql, :string
    field :tags, {:array, :string}, default: []
    field :is_favorite, :boolean, default: false

    belongs_to :workspace, Onesqlx.Workspaces.Workspace
    belongs_to :user, Onesqlx.Accounts.User
    belongs_to :data_source, Onesqlx.DataSources.DataSource

    timestamps(type: :utc_datetime)
  end

  @required_fields [:title, :sql]
  @optional_fields [:description, :tags, :is_favorite, :user_id, :data_source_id]

  def changeset(saved_query, attrs) do
    saved_query
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:title, min: 1, max: 255)
    |> validate_length(:sql, min: 1)
    |> foreign_key_constraint(:workspace_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:data_source_id)
    |> unique_constraint([:workspace_id, :title], error_key: :title)
  end
end
