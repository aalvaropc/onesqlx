defmodule OnesqlxWeb.Plugs.RateLimitTest do
  use OnesqlxWeb.ConnCase, async: true

  import Onesqlx.AccountsFixtures

  alias Onesqlx.Accounts
  alias OnesqlxWeb.Plugs.ApiAuth
  alias OnesqlxWeb.Plugs.RateLimit

  setup do
    # Clean up ETS table entries between tests by using unique scopes
    scope = user_scope_fixture()
    {:ok, raw, _token} = Accounts.create_api_token(scope, "rate-test")
    %{scope: scope, raw_token: raw}
  end

  test "requests under limit pass through", %{raw_token: raw} do
    opts = RateLimit.init(max_requests: 10)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{raw}")
      |> ApiAuth.call([])
      |> RateLimit.call(opts)

    refute conn.halted
    assert get_resp_header(conn, "x-ratelimit-limit") == ["10"]
    assert get_resp_header(conn, "x-ratelimit-remaining") == ["9"]
  end

  test "requests over limit return 429", %{raw_token: raw} do
    opts = RateLimit.init(max_requests: 2)

    for _ <- 1..2 do
      build_conn()
      |> put_req_header("authorization", "Bearer #{raw}")
      |> ApiAuth.call([])
      |> RateLimit.call(opts)
    end

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{raw}")
      |> ApiAuth.call([])
      |> RateLimit.call(opts)

    assert conn.status == 429
    assert conn.halted

    body = Jason.decode!(conn.resp_body)
    assert body["errors"]["detail"] =~ "Rate limit"
  end

  test "different users have independent limits" do
    opts = RateLimit.init(max_requests: 1)

    scope_a = user_scope_fixture()
    {:ok, raw_a, _} = Accounts.create_api_token(scope_a, "user-a")

    scope_b = user_scope_fixture()
    {:ok, raw_b, _} = Accounts.create_api_token(scope_b, "user-b")

    # User A uses their limit
    conn_a =
      build_conn()
      |> put_req_header("authorization", "Bearer #{raw_a}")
      |> ApiAuth.call([])
      |> RateLimit.call(opts)

    refute conn_a.halted

    # User B should still have their own limit
    conn_b =
      build_conn()
      |> put_req_header("authorization", "Bearer #{raw_b}")
      |> ApiAuth.call([])
      |> RateLimit.call(opts)

    refute conn_b.halted
  end

  test "includes rate limit headers", %{raw_token: raw} do
    opts = RateLimit.init(max_requests: 50)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{raw}")
      |> ApiAuth.call([])
      |> RateLimit.call(opts)

    assert get_resp_header(conn, "x-ratelimit-limit") == ["50"]
    assert get_resp_header(conn, "x-ratelimit-remaining") == ["49"]
  end
end
