defmodule OnesqlxWeb.Plugs.ApiAuthTest do
  use OnesqlxWeb.ConnCase, async: true

  import Onesqlx.AccountsFixtures

  alias OnesqlxWeb.Plugs.ApiAuth

  setup do
    scope = user_scope_fixture()
    %{scope: scope}
  end

  test "assigns scope for valid bearer token", %{scope: scope} do
    {:ok, raw, _token} = Onesqlx.Accounts.create_api_token(scope, "test-token")

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{raw}")
      |> ApiAuth.call([])

    assert conn.assigns.current_scope.user.id == scope.user.id
    assert conn.assigns.current_scope.workspace.id == scope.workspace.id
    refute conn.halted
  end

  test "returns 401 for missing authorization header" do
    conn =
      build_conn()
      |> ApiAuth.call([])

    assert conn.status == 401
    assert conn.halted

    body = Jason.decode!(conn.resp_body)
    assert body["errors"]["detail"] =~ "Invalid or missing"
  end

  test "returns 401 for invalid token" do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer invalid-token")
      |> ApiAuth.call([])

    assert conn.status == 401
    assert conn.halted
  end

  test "returns 401 for non-bearer scheme" do
    conn =
      build_conn()
      |> put_req_header("authorization", "Basic abc123")
      |> ApiAuth.call([])

    assert conn.status == 401
    assert conn.halted
  end
end
