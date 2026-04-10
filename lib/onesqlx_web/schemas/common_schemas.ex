defmodule OnesqlxWeb.Schemas.PaginationMeta do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      limit: %Schema{type: :integer, example: 50},
      offset: %Schema{type: :integer, example: 0},
      total: %Schema{type: :integer, example: 100}
    },
    required: [:limit, :offset, :total]
  })
end

defmodule OnesqlxWeb.Schemas.ErrorResponse do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      error: %Schema{
        type: :object,
        properties: %{
          code: %Schema{type: :string, example: "unauthorized"},
          message: %Schema{type: :string, example: "Invalid or missing token"}
        },
        required: [:code]
      }
    },
    required: [:error]
  })
end

defmodule OnesqlxWeb.Schemas.ValidationErrorResponse do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      error: %Schema{
        type: :object,
        properties: %{
          code: %Schema{type: :string, example: "validation_error"},
          details: %Schema{
            type: :object,
            additionalProperties: %Schema{type: :array, items: %Schema{type: :string}}
          }
        },
        required: [:code, :details]
      }
    },
    required: [:error]
  })
end
