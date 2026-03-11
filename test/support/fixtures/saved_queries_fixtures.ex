defmodule Onesqlx.SavedQueriesFixtures do
  @moduledoc """
  Test helpers for creating entities via the `Onesqlx.SavedQueries` context.
  """

  alias Onesqlx.SavedQueries

  def valid_saved_query_attributes(scope, data_source, attrs \\ %{}) do
    Enum.into(attrs, %{
      title: "query-#{System.unique_integer([:positive])}",
      sql: "SELECT 1",
      user_id: scope.user.id,
      data_source_id: data_source.id
    })
  end

  def saved_query_fixture(scope, data_source, attrs \\ %{}) do
    {:ok, saved_query} =
      SavedQueries.create_saved_query(
        scope,
        valid_saved_query_attributes(scope, data_source, attrs)
      )

    saved_query
  end
end
