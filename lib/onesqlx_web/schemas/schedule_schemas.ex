defmodule OnesqlxWeb.Schemas.Schedule do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      name: %Schema{type: :string, example: "Daily Revenue Report"},
      schedule_type: %Schema{type: :string, enum: ~w(hourly daily weekly cron)},
      cron_expression: %Schema{type: :string, nullable: true, example: "0 9 * * *"},
      enabled: %Schema{type: :boolean},
      next_run_at: %Schema{type: :string, format: :"date-time", nullable: true},
      last_run_at: %Schema{type: :string, format: :"date-time", nullable: true},
      notify_email: %Schema{type: :string, nullable: true},
      webhook_url: %Schema{type: :string, nullable: true},
      max_retries: %Schema{type: :integer},
      saved_query_id: %Schema{type: :string, format: :uuid},
      inserted_at: %Schema{type: :string, format: :"date-time"},
      updated_at: %Schema{type: :string, format: :"date-time"}
    }
  })
end

defmodule OnesqlxWeb.Schemas.ScheduleListResponse do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      data: %Schema{type: :array, items: OnesqlxWeb.Schemas.Schedule},
      meta: OnesqlxWeb.Schemas.PaginationMeta
    },
    required: [:data, :meta]
  })
end

defmodule OnesqlxWeb.Schemas.ScheduleShowResponse do
  @moduledoc false
  require OpenApiSpex

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      data: OnesqlxWeb.Schemas.Schedule
    },
    required: [:data]
  })
end

defmodule OnesqlxWeb.Schemas.ScheduleCreateRequest do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      schedule: %Schema{
        type: :object,
        properties: %{
          name: %Schema{type: :string, example: "Daily Revenue Report"},
          schedule_type: %Schema{type: :string, enum: ~w(hourly daily weekly cron)},
          saved_query_id: %Schema{type: :string, format: :uuid},
          cron_expression: %Schema{type: :string, nullable: true},
          notify_email: %Schema{type: :string, nullable: true},
          webhook_url: %Schema{type: :string, nullable: true},
          max_retries: %Schema{type: :integer}
        },
        required: [:name, :schedule_type, :saved_query_id]
      }
    },
    required: [:schedule]
  })
end

defmodule OnesqlxWeb.Schemas.ScheduleUpdateRequest do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      schedule: %Schema{
        type: :object,
        properties: %{
          name: %Schema{type: :string},
          schedule_type: %Schema{type: :string, enum: ~w(hourly daily weekly cron)},
          cron_expression: %Schema{type: :string, nullable: true},
          notify_email: %Schema{type: :string, nullable: true},
          webhook_url: %Schema{type: :string, nullable: true},
          max_retries: %Schema{type: :integer}
        }
      }
    },
    required: [:schedule]
  })
end
