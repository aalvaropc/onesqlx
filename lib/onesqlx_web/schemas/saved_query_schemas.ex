defmodule OnesqlxWeb.Schemas.SavedQuery do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      title: %Schema{type: :string, example: "Revenue by Month"},
      description: %Schema{type: :string, nullable: true},
      sql: %Schema{type: :string, example: "SELECT * FROM orders"},
      tags: %Schema{type: :array, items: %Schema{type: :string}},
      is_favorite: %Schema{type: :boolean},
      data_source_id: %Schema{type: :string, format: :uuid, nullable: true},
      inserted_at: %Schema{type: :string, format: :"date-time"},
      updated_at: %Schema{type: :string, format: :"date-time"}
    }
  })
end

defmodule OnesqlxWeb.Schemas.SavedQueryListResponse do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      data: %Schema{type: :array, items: OnesqlxWeb.Schemas.SavedQuery},
      meta: OnesqlxWeb.Schemas.PaginationMeta
    },
    required: [:data, :meta]
  })
end

defmodule OnesqlxWeb.Schemas.SavedQueryShowResponse do
  @moduledoc false
  require OpenApiSpex

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      data: OnesqlxWeb.Schemas.SavedQuery
    },
    required: [:data]
  })
end

defmodule OnesqlxWeb.Schemas.SavedQueryCreateRequest do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      saved_query: %Schema{
        type: :object,
        properties: %{
          title: %Schema{type: :string, example: "Revenue by Month"},
          sql: %Schema{type: :string, example: "SELECT * FROM orders"},
          description: %Schema{type: :string, nullable: true},
          tags: %Schema{type: :array, items: %Schema{type: :string}},
          data_source_id: %Schema{type: :string, format: :uuid, nullable: true}
        },
        required: [:title, :sql]
      }
    },
    required: [:saved_query]
  })
end

defmodule OnesqlxWeb.Schemas.SavedQueryUpdateRequest do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      saved_query: %Schema{
        type: :object,
        properties: %{
          title: %Schema{type: :string},
          sql: %Schema{type: :string},
          description: %Schema{type: :string, nullable: true},
          tags: %Schema{type: :array, items: %Schema{type: :string}},
          data_source_id: %Schema{type: :string, format: :uuid, nullable: true}
        }
      }
    },
    required: [:saved_query]
  })
end

defmodule OnesqlxWeb.Schemas.ExecuteResultResponse do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      data: %Schema{
        type: :object,
        properties: %{
          columns: %Schema{type: :array, items: %Schema{type: :string}},
          rows: %Schema{type: :array, items: %Schema{type: :array, items: %Schema{}}},
          row_count: %Schema{type: :integer},
          duration_ms: %Schema{type: :integer}
        },
        required: [:columns, :rows, :row_count, :duration_ms]
      }
    },
    required: [:data]
  })
end
