defmodule Onesqlx.Workspaces.WorkspaceMember do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_roles ~w(owner admin member)

  schema "workspace_members" do
    field :role, :string

    belongs_to :workspace, Onesqlx.Workspaces.Workspace
    belongs_to :user, Onesqlx.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def valid_roles, do: @valid_roles

  def changeset(member, attrs) do
    member
    |> cast(attrs, [:role, :workspace_id, :user_id])
    |> validate_required([:role, :workspace_id, :user_id])
    |> validate_inclusion(:role, @valid_roles)
    |> unique_constraint([:workspace_id, :user_id])
  end
end
