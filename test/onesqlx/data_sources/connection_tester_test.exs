defmodule Onesqlx.DataSources.ConnectionTesterTest do
  use Onesqlx.DataCase, async: true

  alias Onesqlx.DataSources.ConnectionTester

  import Onesqlx.AccountsFixtures
  import Onesqlx.DataSourcesFixtures

  @moduletag :integration
  @moduletag timeout: 30_000

  setup do
    Application.put_env(:onesqlx, :connection_module, Onesqlx.DataSources.Connection.Postgrex)

    on_exit(fn ->
      Application.put_env(:onesqlx, :connection_module, Onesqlx.DataSources.MockConnection)
    end)
  end

  defp repo_config, do: test_db_config()

  describe "test_connection/1" do
    test "connects to the local test database" do
      scope = user_scope_fixture()
      config = repo_config()

      ds =
        data_source_fixture(scope, %{
          host: config[:hostname],
          port: config[:port] || 5432,
          database_name: config[:database],
          username: config[:username],
          password: config[:password]
        })

      assert {:ok, %{latency_ms: latency}} = ConnectionTester.test_connection(ds)
      assert is_integer(latency)
      assert latency >= 0
    end
  end

  describe "test_connection_from_attrs/1" do
    test "connects with valid attributes" do
      config = repo_config()

      attrs = %{
        "host" => config[:hostname],
        "port" => to_string(config[:port] || 5432),
        "database_name" => config[:database],
        "username" => config[:username],
        "password" => config[:password],
        "ssl_enabled" => "false"
      }

      assert {:ok, %{latency_ms: latency}} = ConnectionTester.test_connection_from_attrs(attrs)
      assert is_integer(latency)
    end

    test "returns error for invalid host" do
      config = repo_config()

      attrs = %{
        "host" => "nonexistent.invalid.host",
        "port" => "5432",
        "database_name" => "test",
        "username" => config[:username],
        "password" => config[:password]
      }

      assert {:error, message} = ConnectionTester.test_connection_from_attrs(attrs)
      assert message =~ "Host not found"
    end

    test "returns error for invalid password" do
      config = repo_config()

      attrs = %{
        "host" => config[:hostname],
        "port" => to_string(config[:port] || 5432),
        "database_name" => config[:database],
        "username" => config[:username],
        "password" => "wrong_password_#{System.unique_integer([:positive])}"
      }

      assert {:error, message} = ConnectionTester.test_connection_from_attrs(attrs)
      assert message =~ "Invalid username or password"
    end

    test "returns error for nonexistent database" do
      config = repo_config()

      attrs = %{
        "host" => config[:hostname],
        "port" => to_string(config[:port] || 5432),
        "database_name" => "nonexistent_db_#{System.unique_integer([:positive])}",
        "username" => config[:username],
        "password" => config[:password]
      }

      assert {:error, message} = ConnectionTester.test_connection_from_attrs(attrs)
      assert message =~ "Database does not exist"
    end
  end
end
