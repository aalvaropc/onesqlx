defmodule Onesqlx.Catalog.CatalogColumn do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "catalog_columns" do
    field :name, :string
    field :data_type, :string
    field :ordinal_position, :integer
    field :is_nullable, :boolean, default: true
    field :column_default, :string
    field :is_primary_key, :boolean, default: false
    field :character_maximum_length, :integer

    belongs_to :catalog_table, Onesqlx.Catalog.CatalogTable
    belongs_to :data_source, Onesqlx.DataSources.DataSource

    timestamps(type: :utc_datetime)
  end

  def changeset(catalog_column, attrs) do
    catalog_column
    |> cast(attrs, [
      :name,
      :data_type,
      :ordinal_position,
      :is_nullable,
      :column_default,
      :is_primary_key,
      :character_maximum_length,
      :catalog_table_id,
      :data_source_id
    ])
    |> validate_required([
      :name,
      :data_type,
      :ordinal_position,
      :catalog_table_id,
      :data_source_id
    ])
    |> unique_constraint([:catalog_table_id, :name])
  end
end
