defmodule OnesqlxWeb.Api.DataSourceController do
  @moduledoc """
  API controller for data sources.

  Never exposes sensitive connection details (encrypted_password).
  """

  use OnesqlxWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import OnesqlxWeb.ApiPagination

  alias Onesqlx.DataSources
  alias OnesqlxWeb.Schemas

  tags(["Data Sources"])
  security([%{"bearer" => []}])

  operation(:index,
    summary: "List data sources",
    parameters: [
      limit: [in: :query, schema: %OpenApiSpex.Schema{type: :integer}, required: false],
      offset: [in: :query, schema: %OpenApiSpex.Schema{type: :integer}, required: false]
    ],
    responses: [ok: {"Data source list", "application/json", Schemas.DataSourceListResponse}]
  )

  def index(conn, params) do
    scope = conn.assigns.current_scope
    pagination = extract_pagination(params)
    data_sources = DataSources.list_data_sources(scope, pagination)
    total = DataSources.count_data_sources(scope)

    json(conn, %{
      data: Enum.map(data_sources, &serialize_data_source/1),
      meta: pagination_meta(pagination[:limit], pagination[:offset], total)
    })
  end

  defp serialize_data_source(ds) do
    %{
      id: ds.id,
      name: ds.name,
      host: ds.host,
      port: ds.port,
      database_name: ds.database_name,
      username: ds.username,
      ssl_enabled: ds.ssl_enabled,
      status: ds.status,
      inserted_at: ds.inserted_at,
      updated_at: ds.updated_at
    }
  end
end
