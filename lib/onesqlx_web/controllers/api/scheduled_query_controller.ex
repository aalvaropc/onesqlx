defmodule OnesqlxWeb.Api.ScheduledQueryController do
  @moduledoc """
  API controller for scheduled queries.
  """

  use OnesqlxWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import OnesqlxWeb.ApiPagination

  alias Onesqlx.Scheduling
  alias OnesqlxWeb.Schemas

  tags(["Schedules"])
  security([%{"bearer" => []}])

  operation(:index,
    summary: "List schedules",
    parameters: [
      limit: [in: :query, schema: %OpenApiSpex.Schema{type: :integer}, required: false],
      offset: [in: :query, schema: %OpenApiSpex.Schema{type: :integer}, required: false]
    ],
    responses: [ok: {"Schedule list", "application/json", Schemas.ScheduleListResponse}]
  )

  operation(:show,
    summary: "Get a schedule",
    parameters: [
      id: [in: :path, schema: %OpenApiSpex.Schema{type: :string, format: :uuid}, required: true]
    ],
    responses: [
      ok: {"Schedule details", "application/json", Schemas.ScheduleShowResponse},
      not_found: {"Not found", "application/json", Schemas.ErrorResponse}
    ]
  )

  operation(:create,
    summary: "Create a schedule",
    request_body: {"Schedule params", "application/json", Schemas.ScheduleCreateRequest},
    responses: [
      created: {"Created schedule", "application/json", Schemas.ScheduleShowResponse},
      unprocessable_entity:
        {"Validation errors", "application/json", Schemas.ValidationErrorResponse}
    ]
  )

  operation(:update,
    summary: "Update a schedule",
    parameters: [
      id: [in: :path, schema: %OpenApiSpex.Schema{type: :string, format: :uuid}, required: true]
    ],
    request_body: {"Schedule params", "application/json", Schemas.ScheduleUpdateRequest},
    responses: [
      ok: {"Updated schedule", "application/json", Schemas.ScheduleShowResponse},
      unprocessable_entity:
        {"Validation errors", "application/json", Schemas.ValidationErrorResponse}
    ]
  )

  operation(:delete,
    summary: "Delete a schedule",
    parameters: [
      id: [in: :path, schema: %OpenApiSpex.Schema{type: :string, format: :uuid}, required: true]
    ],
    responses: [no_content: "Deleted"]
  )

  def index(conn, params) do
    scope = conn.assigns.current_scope
    pagination = extract_pagination(params)
    schedules = Scheduling.list_scheduled_queries(scope, pagination)
    total = Scheduling.count_scheduled_queries(scope)

    json(conn, %{
      data: Enum.map(schedules, &serialize_schedule/1),
      meta: pagination_meta(pagination[:limit], pagination[:offset], total)
    })
  end

  def show(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope
    schedule = Scheduling.get_scheduled_query!(scope, id)
    json(conn, %{data: serialize_schedule(schedule)})
  end

  def create(conn, %{"schedule" => params}) do
    scope = conn.assigns.current_scope

    case Scheduling.create_scheduled_query(scope, params) do
      {:ok, schedule} ->
        conn
        |> put_status(:created)
        |> json(%{data: serialize_schedule(schedule)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: format_errors(changeset)})
    end
  end

  def update(conn, %{"id" => id, "schedule" => params}) do
    scope = conn.assigns.current_scope
    schedule = Scheduling.get_scheduled_query!(scope, id)

    case Scheduling.update_scheduled_query(scope, schedule, params) do
      {:ok, schedule} ->
        json(conn, %{data: serialize_schedule(schedule)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: format_errors(changeset)})
    end
  end

  def delete(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope
    schedule = Scheduling.get_scheduled_query!(scope, id)
    {:ok, _} = Scheduling.delete_scheduled_query(scope, schedule)
    send_resp(conn, :no_content, "")
  end

  defp serialize_schedule(s) do
    %{
      id: s.id,
      name: s.name,
      schedule_type: s.schedule_type,
      cron_expression: s.cron_expression,
      enabled: s.enabled,
      next_run_at: s.next_run_at,
      last_run_at: s.last_run_at,
      notify_email: s.notify_email,
      webhook_url: s.webhook_url,
      max_retries: s.max_retries,
      saved_query_id: s.saved_query_id,
      inserted_at: s.inserted_at,
      updated_at: s.updated_at
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
