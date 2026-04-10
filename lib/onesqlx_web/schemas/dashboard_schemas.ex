defmodule OnesqlxWeb.Schemas.Dashboard do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      title: %Schema{type: :string, example: "Sales Dashboard"},
      description: %Schema{type: :string, nullable: true},
      inserted_at: %Schema{type: :string, format: :"date-time"},
      updated_at: %Schema{type: :string, format: :"date-time"}
    }
  })
end

defmodule OnesqlxWeb.Schemas.DashboardCard do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      title: %Schema{type: :string, nullable: true},
      type: %Schema{type: :string, enum: ~w(table kpi bar line pie doughnut area scatter)},
      position: %Schema{type: :integer},
      saved_query_title: %Schema{type: :string, nullable: true}
    }
  })
end

defmodule OnesqlxWeb.Schemas.DashboardShowResponse do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      data: %Schema{
        type: :object,
        allOf: [
          OnesqlxWeb.Schemas.Dashboard,
          %Schema{
            type: :object,
            properties: %{
              cards: %Schema{type: :array, items: OnesqlxWeb.Schemas.DashboardCard}
            }
          }
        ]
      }
    },
    required: [:data]
  })
end

defmodule OnesqlxWeb.Schemas.DashboardListResponse do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      data: %Schema{type: :array, items: OnesqlxWeb.Schemas.Dashboard},
      meta: OnesqlxWeb.Schemas.PaginationMeta
    },
    required: [:data, :meta]
  })
end

defmodule OnesqlxWeb.Schemas.DashboardCreateRequest do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      dashboard: %Schema{
        type: :object,
        properties: %{
          title: %Schema{type: :string, example: "Sales Dashboard"},
          description: %Schema{type: :string, nullable: true}
        },
        required: [:title]
      }
    },
    required: [:dashboard]
  })
end
