defmodule OnesqlxWeb.Api.DashboardController do
  @moduledoc """
  API controller for dashboards.
  """

  use OnesqlxWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import OnesqlxWeb.ApiPagination

  alias Onesqlx.Dashboards
  alias OnesqlxWeb.Schemas

  tags(["Dashboards"])
  security([%{"bearer" => []}])

  operation(:index,
    summary: "List dashboards",
    parameters: [
      limit: [in: :query, schema: %OpenApiSpex.Schema{type: :integer}, required: false],
      offset: [in: :query, schema: %OpenApiSpex.Schema{type: :integer}, required: false]
    ],
    responses: [ok: {"Dashboard list", "application/json", Schemas.DashboardListResponse}]
  )

  operation(:show,
    summary: "Get a dashboard with cards",
    parameters: [
      id: [in: :path, schema: %OpenApiSpex.Schema{type: :string, format: :uuid}, required: true]
    ],
    responses: [
      ok: {"Dashboard details", "application/json", Schemas.DashboardShowResponse},
      not_found: {"Not found", "application/json", Schemas.ErrorResponse}
    ]
  )

  operation(:create,
    summary: "Create a dashboard",
    request_body: {"Dashboard params", "application/json", Schemas.DashboardCreateRequest},
    responses: [
      created: {"Created dashboard", "application/json", Schemas.DashboardShowResponse},
      unprocessable_entity:
        {"Validation errors", "application/json", Schemas.ValidationErrorResponse}
    ]
  )

  operation(:delete,
    summary: "Delete a dashboard",
    parameters: [
      id: [in: :path, schema: %OpenApiSpex.Schema{type: :string, format: :uuid}, required: true]
    ],
    responses: [no_content: "Deleted"]
  )

  def create(conn, %{"dashboard" => params}) do
    scope = conn.assigns.current_scope

    case Dashboards.create_dashboard(scope, params) do
      {:ok, dashboard} ->
        conn
        |> put_status(:created)
        |> json(%{data: serialize_dashboard(dashboard)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: format_errors(changeset)})
    end
  end

  def delete(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope
    dashboard = Dashboards.get_dashboard!(scope, id)
    {:ok, _} = Dashboards.delete_dashboard(scope, dashboard)
    send_resp(conn, :no_content, "")
  end

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

  defp format_errors(changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
      end)

    %{code: "validation_error", details: errors}
  end
end
