defmodule OnesqlxWeb.ApiSpec do
  @moduledoc """
  OpenAPI specification for the OneSQLx API.
  """

  alias OpenApiSpex.{Info, OpenApi, SecurityScheme, Server}

  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      info: %Info{
        title: "OneSQLx API",
        version: "1.0.0",
        description:
          "SQL-first analytics platform API for managing queries, dashboards, and schedules."
      },
      servers: [%Server{url: "/"}],
      paths: OpenApiSpex.Paths.from_router(OnesqlxWeb.Router),
      components: %OpenApiSpex.Components{
        securitySchemes: %{
          "bearer" => %SecurityScheme{
            type: "http",
            scheme: "bearer",
            description: "API token authentication. Generate tokens from the API Tokens page."
          }
        }
      },
      security: [%{"bearer" => []}]
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
