defmodule OnesqlxWeb.Plugs.MetricsAuthTest do
  # async: false — the plug reads global application env
  use OnesqlxWeb.ConnCase, async: false

  setup do
    original = Application.fetch_env(:onesqlx, :metrics_auth)

    on_exit(fn ->
      case original do
        {:ok, value} -> Application.put_env(:onesqlx, :metrics_auth, value)
        :error -> Application.delete_env(:onesqlx, :metrics_auth)
      end
    end)

    :ok
  end

  test "GET /metrics is open when :metrics_auth is not configured", %{conn: conn} do
    Application.delete_env(:onesqlx, :metrics_auth)

    conn = get(conn, ~p"/metrics")
    assert conn.status == 200
  end

  test "GET /metrics responds 404 when disabled", %{conn: conn} do
    Application.put_env(:onesqlx, :metrics_auth, :disabled)

    conn = get(conn, ~p"/metrics")
    assert conn.status == 404
  end

  test "GET /metrics responds 401 without a token", %{conn: conn} do
    Application.put_env(:onesqlx, :metrics_auth, {:token, "s3cret"})

    conn = get(conn, ~p"/metrics")
    assert conn.status == 401
  end

  test "GET /metrics responds 401 with a wrong token", %{conn: conn} do
    Application.put_env(:onesqlx, :metrics_auth, {:token, "s3cret"})

    conn =
      conn
      |> put_req_header("authorization", "Bearer wrong")
      |> get(~p"/metrics")

    assert conn.status == 401
  end

  test "GET /metrics responds 200 with the correct bearer token", %{conn: conn} do
    Application.put_env(:onesqlx, :metrics_auth, {:token, "s3cret"})

    conn =
      conn
      |> put_req_header("authorization", "Bearer s3cret")
      |> get(~p"/metrics")

    assert conn.status == 200
  end
end
