defmodule Onesqlx.SchedulingFixtures do
  @moduledoc """
  Test helpers for creating entities via the `Onesqlx.Scheduling` context.
  """

  alias Onesqlx.Scheduling

  def valid_scheduled_query_attributes(saved_query, attrs \\ %{}) do
    Enum.into(attrs, %{
      name: "schedule-#{System.unique_integer([:positive])}",
      schedule_type: "daily",
      saved_query_id: saved_query.id
    })
  end

  def scheduled_query_fixture(scope, saved_query, attrs \\ %{}) do
    {:ok, scheduled_query} =
      Scheduling.create_scheduled_query(
        scope,
        valid_scheduled_query_attributes(saved_query, attrs)
      )

    scheduled_query
  end
end
