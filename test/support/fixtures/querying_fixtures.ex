defmodule Onesqlx.QueryingFixtures do
  @moduledoc """
  Test helpers for creating entities via the `Onesqlx.Querying` context.
  """

  alias Onesqlx.Querying

  def valid_query_run_attributes(scope, data_source, attrs \\ %{}) do
    Enum.into(attrs, %{
      sql: "SELECT 1",
      status: "success",
      duration_ms: 42,
      row_count: 1,
      executed_at: DateTime.utc_now(:second),
      user_id: scope.user.id,
      data_source_id: data_source.id
    })
  end

  def query_run_fixture(scope, data_source, attrs \\ %{}) do
    {:ok, query_run} =
      Querying.record_query_run(scope, valid_query_run_attributes(scope, data_source, attrs))

    query_run
  end
end
