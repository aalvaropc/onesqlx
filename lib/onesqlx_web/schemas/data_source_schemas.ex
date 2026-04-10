defmodule OnesqlxWeb.Schemas.DataSource do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      name: %Schema{type: :string, example: "Production DB"},
      host: %Schema{type: :string, example: "db.example.com"},
      port: %Schema{type: :integer, example: 5432},
      database_name: %Schema{type: :string, example: "analytics"},
      username: %Schema{type: :string, example: "readonly_user"},
      ssl_enabled: %Schema{type: :boolean},
      status: %Schema{type: :string, enum: ~w(pending connected error)},
      inserted_at: %Schema{type: :string, format: :"date-time"},
      updated_at: %Schema{type: :string, format: :"date-time"}
    }
  })
end

defmodule OnesqlxWeb.Schemas.DataSourceListResponse do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      data: %Schema{type: :array, items: OnesqlxWeb.Schemas.DataSource},
      meta: OnesqlxWeb.Schemas.PaginationMeta
    },
    required: [:data, :meta]
  })
end
