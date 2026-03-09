defmodule Onesqlx.DataSourcesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Onesqlx.DataSources` context.
  """

  alias Onesqlx.DataSources

  def valid_data_source_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: "test-db-#{System.unique_integer([:positive])}",
      host: "localhost",
      port: 5432,
      database_name: "test_db",
      username: "postgres",
      password: "postgres"
    })
  end

  def data_source_fixture(scope, attrs \\ %{}) do
    {:ok, data_source} =
      scope
      |> DataSources.create_data_source(valid_data_source_attributes(attrs))

    data_source
  end
end
