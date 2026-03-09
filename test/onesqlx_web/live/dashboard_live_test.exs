defmodule OnesqlxWeb.DashboardLiveTest do
  use OnesqlxWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "authenticated access" do
    setup :register_and_log_in_user

    test "renders dashboard for authenticated user", %{conn: conn, user: user} do
      {:ok, _lv, html} = live(conn, ~p"/dashboard")
      assert html =~ "Dashboard"
      assert html =~ user.email
    end
  end

  describe "unauthenticated access" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/dashboard")
      assert {:redirect, %{to: path}} = redirect
      assert path =~ ~p"/users/log-in"
    end
  end
end
