defmodule Onesqlx.Accounts.ApiToken do
  @moduledoc """
  Schema for API authentication tokens.

  Tokens are generated as random base64 strings, but only the SHA-256 hash
  is stored. The raw token is shown once at creation and cannot be recovered.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Onesqlx.Accounts.Scope
  alias Onesqlx.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "api_tokens" do
    field :name, :string
    field :token_hash, :binary
    field :last_used_at, :utc_datetime
    field :expires_at, :utc_datetime

    belongs_to :user, Onesqlx.Accounts.User
    belongs_to :workspace, Onesqlx.Workspaces.Workspace

    timestamps(type: :utc_datetime)
  end

  @required_fields [:name]
  @optional_fields [:expires_at]

  def changeset(token, attrs) do
    token
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 1, max: 100)
    |> unique_constraint([:user_id, :name], error_key: :name)
    |> unique_constraint(:token_hash)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:workspace_id)
  end

  @doc """
  Generates a raw token and builds an ApiToken struct with the hashed version.

  Returns `{raw_token, %ApiToken{}}` where the raw token should be shown
  to the user once and never stored.
  """
  def build_token(user, workspace, name) do
    raw = Base.url_encode64(:crypto.strong_rand_bytes(32))
    hash = :crypto.hash(:sha256, raw)

    token = %__MODULE__{
      user_id: user.id,
      workspace_id: workspace.id,
      name: name,
      token_hash: hash
    }

    {raw, token}
  end

  @doc """
  Verifies a raw token and returns the user and workspace if valid.

  Returns `{:ok, user, workspace}` or `:error`.
  """
  def verify_token(raw_token) when is_binary(raw_token) do
    hash = :crypto.hash(:sha256, raw_token)

    query =
      from(t in __MODULE__,
        where: t.token_hash == ^hash,
        where: is_nil(t.expires_at) or t.expires_at > ^DateTime.utc_now(:second),
        preload: [:user, :workspace]
      )

    case Repo.one(query) do
      nil ->
        :error

      token ->
        {:ok, token.user, token.workspace}
    end
  end

  def verify_token(_), do: :error

  @doc """
  Updates the `last_used_at` timestamp for a token identified by raw token.
  """
  def touch_usage(raw_token) do
    hash = :crypto.hash(:sha256, raw_token)

    from(t in __MODULE__, where: t.token_hash == ^hash)
    |> Repo.update_all(set: [last_used_at: DateTime.utc_now(:second)])
  end

  @doc """
  Returns a scope for the given raw API token, or `:error`.
  """
  def get_scope(raw_token) do
    case verify_token(raw_token) do
      {:ok, user, workspace} ->
        touch_usage(raw_token)
        {:ok, Scope.for_user(user, workspace)}

      :error ->
        :error
    end
  end
end
