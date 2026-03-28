defmodule OnesqlxWeb.Api.DataSourceController do
  @moduledoc """
  API controller for data sources.

  Never exposes sensitive connection details (encrypted_password).
  """

  use OnesqlxWeb, :controller

  alias Onesqlx.DataSources

  def index(conn, _params) do
    scope = conn.assigns.current_scope
    data_sources = DataSources.list_data_sources(scope)
    json(conn, %{data: Enum.map(data_sources, &serialize_data_source/1)})
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
