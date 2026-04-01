defmodule OnesqlxWeb.Api.DashboardController do
  @moduledoc """
  API controller for dashboards.
  """

  use OnesqlxWeb, :controller

  import OnesqlxWeb.ApiPagination

  alias Onesqlx.Dashboards

  def index(conn, params) do
    scope = conn.assigns.current_scope
    pagination = extract_pagination(params)
    dashboards = Dashboards.list_dashboards(scope, pagination)
    total = Dashboards.count_dashboards(scope)

    json(conn, %{
      data: Enum.map(dashboards, &serialize_dashboard/1),
      meta: pagination_meta(pagination[:limit], pagination[:offset], total)
    })
  end

  def show(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope
    dashboard = Dashboards.get_dashboard_with_cards!(scope, id)

    json(conn, %{
      data:
        serialize_dashboard(dashboard)
        |> Map.put(:cards, Enum.map(dashboard.cards, &serialize_card/1))
    })
  end

  defp serialize_dashboard(d) do
    %{
      id: d.id,
      title: d.title,
      description: d.description,
      inserted_at: d.inserted_at,
      updated_at: d.updated_at
    }
  end

  defp serialize_card(c) do
    %{
      id: c.id,
      title: c.title,
      type: c.type,
      position: c.position,
      saved_query_title: c.saved_query && c.saved_query.title
    }
  end
end
