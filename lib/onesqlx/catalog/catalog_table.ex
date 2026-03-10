defmodule Onesqlx.Catalog.CatalogTable do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "catalog_tables" do
    field :name, :string
    field :table_type, :string, default: "BASE TABLE"
    field :estimated_row_count, :integer

    belongs_to :catalog_schema, Onesqlx.Catalog.CatalogSchema
    belongs_to :data_source, Onesqlx.DataSources.DataSource
    has_many :catalog_columns, Onesqlx.Catalog.CatalogColumn

    timestamps(type: :utc_datetime)
  end

  @valid_table_types ~w(BASE TABLE VIEW MATERIALIZED VIEW)

  def changeset(catalog_table, attrs) do
    catalog_table
    |> cast(attrs, [:name, :table_type, :estimated_row_count, :catalog_schema_id, :data_source_id])
    |> validate_required([:name, :table_type, :catalog_schema_id, :data_source_id])
    |> validate_inclusion(:table_type, @valid_table_types)
    |> unique_constraint([:catalog_schema_id, :name])
  end
end
