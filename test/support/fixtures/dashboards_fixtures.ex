defmodule Onesqlx.DashboardsFixtures do
  @moduledoc """
  Test helpers for creating entities via the `Onesqlx.Dashboards` context.
  """

  alias Onesqlx.Dashboards

  def valid_dashboard_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      title: "dashboard-#{System.unique_integer([:positive])}"
    })
  end

  def dashboard_fixture(scope, attrs \\ %{}) do
    {:ok, dashboard} =
      Dashboards.create_dashboard(scope, valid_dashboard_attributes(attrs))

    dashboard
  end

  def valid_card_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      type: "table"
    })
  end

  def card_fixture(scope, dashboard, saved_query, attrs \\ %{}) do
    {:ok, card} =
      Dashboards.add_card(
        scope,
        dashboard,
        valid_card_attributes(Map.put(attrs, :saved_query_id, saved_query.id))
      )

    card
  end
end
