defmodule Onesqlx.Dashboards.DashboardCard do
  @moduledoc """
  Schema for dashboard cards.

  Each card is linked to a saved query and renders its result as a table,
  KPI value, bar chart, or line chart.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @valid_types ~w(table kpi bar line)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "dashboard_cards" do
    field :title, :string
    field :type, :string, default: "table"
    field :position, :integer, default: 0
    field :config, :map, default: %{}

    belongs_to :dashboard, Onesqlx.Dashboards.Dashboard
    belongs_to :saved_query, Onesqlx.SavedQueries.SavedQuery

    timestamps(type: :utc_datetime)
  end

  @required_fields [:type, :position]
  @optional_fields [:title, :saved_query_id, :config]

  def changeset(card, attrs) do
    card
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:type, @valid_types)
    |> foreign_key_constraint(:dashboard_id)
    |> foreign_key_constraint(:saved_query_id)
  end
end
