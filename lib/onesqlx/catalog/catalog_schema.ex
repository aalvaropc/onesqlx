defmodule Onesqlx.Catalog.CatalogSchema do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "catalog_schemas" do
    field :name, :string

    belongs_to :data_source, Onesqlx.DataSources.DataSource
    has_many :catalog_tables, Onesqlx.Catalog.CatalogTable

    timestamps(type: :utc_datetime)
  end

  def changeset(catalog_schema, attrs) do
    catalog_schema
    |> cast(attrs, [:name, :data_source_id])
    |> validate_required([:name, :data_source_id])
    |> unique_constraint([:data_source_id, :name])
  end
end
