defmodule OnesqlxWeb.DataSourceLive.NewTest do
  use OnesqlxWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "New" do
    test "renders form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/data-sources/new")
      assert html =~ "New Data Source"
      assert html =~ "Name"
      assert html =~ "Host"
      assert html =~ "Port"
      assert html =~ "Database Name"
      assert html =~ "Username"
      assert html =~ "Password"
    end

    test "validates required fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/data-sources/new")

      html =
        view
        |> form("#data-source-form", data_source: %{name: ""})
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end

    test "saves and redirects on valid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/data-sources/new")

      {:ok, _view, html} =
        view
        |> form("#data-source-form",
          data_source: %{
            name: "prod-analytics",
            host: "db.example.com",
            port: 5432,
            database_name: "analytics",
            username: "reader",
            password: "secret123"
          }
        )
        |> render_submit()
        |> follow_redirect(conn, ~p"/data-sources")

      assert html =~ "Data source created successfully"
      assert html =~ "prod-analytics"
    end

    test "shows validation errors on save", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/data-sources/new")

      html =
        view
        |> form("#data-source-form", data_source: %{name: "", host: "", password: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end
  end
end
