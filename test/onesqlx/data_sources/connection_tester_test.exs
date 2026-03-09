defmodule Onesqlx.DataSources.ConnectionTesterTest do
  use Onesqlx.DataCase, async: true

  alias Onesqlx.DataSources.ConnectionTester

  import Onesqlx.AccountsFixtures
  import Onesqlx.DataSourcesFixtures

  @moduletag timeout: 30_000

  describe "test_connection/1" do
    test "connects to the local test database" do
      scope = user_scope_fixture()

      ds =
        data_source_fixture(scope, %{
          host: "localhost",
          port: 5432,
          database_name: "onesqlx_test#{System.get_env("MIX_TEST_PARTITION")}",
          username: "postgres",
          password: "postgres"
        })

      assert {:ok, %{latency_ms: latency}} = ConnectionTester.test_connection(ds)
      assert is_integer(latency)
      assert latency >= 0
    end
  end

  describe "test_connection_from_attrs/1" do
    test "connects with valid attributes" do
      attrs = %{
        "host" => "localhost",
        "port" => "5432",
        "database_name" => "onesqlx_test#{System.get_env("MIX_TEST_PARTITION")}",
        "username" => "postgres",
        "password" => "postgres",
        "ssl_enabled" => "false"
      }

      assert {:ok, %{latency_ms: latency}} = ConnectionTester.test_connection_from_attrs(attrs)
      assert is_integer(latency)
    end

    test "returns error for invalid host" do
      attrs = %{
        "host" => "nonexistent.invalid.host",
        "port" => "5432",
        "database_name" => "test",
        "username" => "postgres",
        "password" => "postgres"
      }

      assert {:error, message} = ConnectionTester.test_connection_from_attrs(attrs)
      assert message =~ "Host not found"
    end

    test "returns error for invalid password" do
      attrs = %{
        "host" => "localhost",
        "port" => "5432",
        "database_name" => "onesqlx_test#{System.get_env("MIX_TEST_PARTITION")}",
        "username" => "postgres",
        "password" => "wrong_password"
      }

      assert {:error, message} = ConnectionTester.test_connection_from_attrs(attrs)
      assert message =~ "Invalid username or password"
    end

    test "returns error for nonexistent database" do
      attrs = %{
        "host" => "localhost",
        "port" => "5432",
        "database_name" => "nonexistent_db_#{System.unique_integer([:positive])}",
        "username" => "postgres",
        "password" => "postgres"
      }

      assert {:error, message} = ConnectionTester.test_connection_from_attrs(attrs)
      assert message =~ "Database does not exist"
    end
  end
end
