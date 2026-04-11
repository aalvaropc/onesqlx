defmodule Onesqlx.Snippets.SqlSnippet do
  @moduledoc """
  Schema for reusable SQL snippets.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "sql_snippets" do
    field :title, :string
    field :sql, :string
    field :description, :string

    belongs_to :workspace, Onesqlx.Workspaces.Workspace
    belongs_to :user, Onesqlx.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @required_fields [:title, :sql]
  @optional_fields [:description, :user_id]

  def changeset(snippet, attrs) do
    snippet
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:title, min: 1, max: 255)
    |> validate_length(:sql, min: 1)
    |> unique_constraint([:workspace_id, :title], error_key: :title)
    |> foreign_key_constraint(:workspace_id)
    |> foreign_key_constraint(:user_id)
  end
end
