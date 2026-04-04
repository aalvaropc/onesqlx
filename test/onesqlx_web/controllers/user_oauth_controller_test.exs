defmodule OnesqlxWeb.UserOAuthControllerTest do
  use OnesqlxWeb.ConnCase, async: true

  describe "GET /auth/:provider/callback" do
    test "redirects to login on auth failure", %{conn: conn} do
      # Simulate Ueberauth failure by hitting callback without valid auth
      conn = get(conn, ~p"/auth/github/callback")
      assert redirected_to(conn) =~ "/users/log-in"
    end
  end

  describe "GET /auth/:provider" do
    test "request action redirects for unsupported provider", %{conn: conn} do
      conn = get(conn, ~p"/auth/unsupported")
      assert redirected_to(conn) =~ "/users/log-in"
    end
  end
end
