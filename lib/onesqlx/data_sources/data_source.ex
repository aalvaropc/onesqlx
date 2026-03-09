defmodule Onesqlx.DataSources.DataSource do
  use Ecto.Schema
  import Ecto.Changeset

  alias Onesqlx.DataSources.Encryption

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "data_sources" do
    field :name, :string
    field :adapter, :string, default: "postgresql"
    field :host, :string
    field :port, :integer, default: 5432
    field :database_name, :string
    field :username, :string
    field :password, :string, virtual: true, redact: true
    field :encrypted_password, :binary
    field :ssl_enabled, :boolean, default: false
    field :read_only, :boolean, default: true
    field :status, :string, default: "pending"

    belongs_to :workspace, Onesqlx.Workspaces.Workspace

    timestamps(type: :utc_datetime)
  end

  @valid_statuses ~w(pending connected error)
  @valid_adapters ~w(postgresql)

  @cast_fields [
    :name,
    :host,
    :port,
    :database_name,
    :username,
    :password,
    :ssl_enabled,
    :read_only,
    :adapter,
    :status
  ]

  def changeset(data_source, attrs) do
    data_source
    |> cast(attrs, @cast_fields)
    |> validate_required([:name, :host, :port, :database_name, :username])
    |> maybe_require_password()
    |> validate_length(:name, min: 2, max: 100)
    |> validate_number(:port, greater_than_or_equal_to: 1, less_than_or_equal_to: 65_535)
    |> validate_inclusion(:adapter, @valid_adapters)
    |> validate_inclusion(:status, @valid_statuses)
    |> unique_constraint([:workspace_id, :name], error_key: :name)
    |> maybe_encrypt_password()
  end

  def status_changeset(data_source, attrs) do
    data_source
    |> cast(attrs, [:status])
    |> validate_required([:status])
    |> validate_inclusion(:status, @valid_statuses)
  end

  defp maybe_require_password(changeset) do
    if changeset.data.__meta__.state == :built do
      validate_required(changeset, [:password])
    else
      changeset
    end
  end

  defp maybe_encrypt_password(changeset) do
    case get_change(changeset, :password) do
      nil ->
        changeset

      password ->
        changeset
        |> put_change(:encrypted_password, Encryption.encrypt(password))
        |> delete_change(:password)
    end
  end
end
