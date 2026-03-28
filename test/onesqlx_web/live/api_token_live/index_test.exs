defmodule OnesqlxWeb.ApiTokenLive.IndexTest do
  use OnesqlxWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "Index" do
    test "renders empty state", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/settings/api-tokens")
      assert html =~ "No API tokens yet"
    end

    test "lists existing tokens", %{conn: conn, scope: scope} do
      {:ok, _raw, _token} = Onesqlx.Accounts.create_api_token(scope, "my-token")

      {:ok, _lv, html} = live(conn, ~p"/settings/api-tokens")
      assert html =~ "my-token"
    end

    test "opens create modal", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/settings/api-tokens")
      lv |> element("button", "Create Token") |> render_click()
      assert has_element?(lv, "form[phx-submit='create_token']")
    end

    test "creates token and shows raw value", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/settings/api-tokens")
      lv |> element("button", "Create Token") |> render_click()

      html =
        lv
        |> form("form[phx-submit='create_token']", %{name: "new-key"})
        |> render_submit()

      assert html =~ "Token Created"
      assert html =~ "Copy this token now"
    end

    test "revokes token", %{conn: conn, scope: scope} do
      {:ok, _raw, token} = Onesqlx.Accounts.create_api_token(scope, "revoke-me")

      {:ok, lv, _html} = live(conn, ~p"/settings/api-tokens")
      assert has_element?(lv, "#tokens", "revoke-me")

      lv
      |> element("[phx-click='revoke'][phx-value-id='#{token.id}']")
      |> render_click()

      refute has_element?(lv, "#tokens", "revoke-me")
    end

    test "redirects unauthenticated", %{conn: conn} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.delete_session(:user_token)

      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/settings/api-tokens")
      assert path =~ "/users/log-in"
    end
  end
end
