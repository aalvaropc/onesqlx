defmodule Onesqlx.Workspaces.WorkspaceInvitation do
  @moduledoc """
  An email invitation to join a workspace with a given role.

  The raw token travels only in the invitation email; the database
  stores its SHA-256 hash (same pattern as `Accounts.ApiToken`).
  Invitations expire after #{7} days and are bound to the invited email:
  only a user logged in with that address can accept.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  # Ownership is granted by hand, never by invitation
  @invitable_roles ~w(admin member viewer)
  @validity_days 7

  schema "workspace_invitations" do
    field :email, :string
    field :role, :string, default: "member"
    field :token_hash, :binary
    field :expires_at, :utc_datetime
    field :accepted_at, :utc_datetime

    belongs_to :workspace, Onesqlx.Workspaces.Workspace
    belongs_to :invited_by, Onesqlx.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def invitable_roles, do: @invitable_roles

  @doc """
  Builds an unsaved invitation plus the raw token to email. The raw
  token is shown once and never stored.
  """
  def build(workspace, invited_by, attrs) do
    raw = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    expires_at = DateTime.add(DateTime.utc_now(:second), @validity_days, :day)

    changeset =
      %__MODULE__{
        workspace_id: workspace.id,
        invited_by_id: invited_by.id,
        token_hash: :crypto.hash(:sha256, raw),
        expires_at: expires_at
      }
      |> changeset(attrs)

    {raw, changeset}
  end

  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:email, :role])
    |> validate_required([:email, :role])
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must be a valid email address"
    )
    |> validate_length(:email, max: 160)
    |> validate_inclusion(:role, @invitable_roles)
    |> unique_constraint([:workspace_id, :email],
      name: :workspace_invitations_pending_unique,
      error_key: :email,
      message: "already has a pending invitation"
    )
  end

  @doc "Hashes a raw token for lookup."
  def hash_token(raw) when is_binary(raw), do: :crypto.hash(:sha256, raw)
end
