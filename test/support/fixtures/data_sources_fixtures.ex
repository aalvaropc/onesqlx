defmodule Onesqlx.DataSourcesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Onesqlx.DataSources` context.
  """

  alias Onesqlx.DataSources

  @doc """
  Returns the test database connection config from the Repo configuration.
  """
  def test_db_config do
    Application.get_env(:onesqlx, Onesqlx.Repo)
  end

  def valid_data_source_attributes(attrs \\ %{}) do
    config = test_db_config()

    Enum.into(attrs, %{
      name: "test-db-#{System.unique_integer([:positive])}",
      host: config[:hostname],
      port: config[:port] || 5432,
      database_name: "test_db",
      username: config[:username],
      password: config[:password]
    })
  end

  def data_source_fixture(scope, attrs \\ %{}) do
    {:ok, data_source} =
      scope
      |> DataSources.create_data_source(valid_data_source_attributes(attrs))

    data_source
  end
end
