defmodule OnesqlxWeb.CatalogLive.ExplorerTest do
  use OnesqlxWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Onesqlx.CatalogFixtures
  import Onesqlx.DataSourcesFixtures

  setup :register_and_log_in_user

  setup %{scope: scope} do
    data_source = data_source_fixture(scope)
    %{data_source: data_source, scope: scope}
  end

  describe "Explorer" do
    test "renders empty state when no catalog data", %{conn: conn, data_source: ds} do
      {:ok, _view, html} = live(conn, ~p"/data-sources/#{ds.id}/catalog")
      assert html =~ "No catalog data"
      assert html =~ "Sync Catalog"
    end

    test "renders schema names", %{conn: conn, data_source: ds} do
      catalog_schema_fixture(ds, %{name: "public"})
      catalog_schema_fixture(ds, %{name: "analytics"})

      {:ok, _view, html} = live(conn, ~p"/data-sources/#{ds.id}/catalog")
      assert html =~ "public"
      assert html =~ "analytics"
    end

    test "selecting schema shows tables", %{conn: conn, data_source: ds} do
      schema = catalog_schema_fixture(ds, %{name: "public"})
      catalog_table_fixture(ds, schema, %{name: "users"})
      catalog_table_fixture(ds, schema, %{name: "orders"})

      {:ok, view, _html} = live(conn, ~p"/data-sources/#{ds.id}/catalog")
      html = view |> element("button", "public") |> render_click()

      assert html =~ "users"
      assert html =~ "orders"
    end

    test "selecting table shows columns with types and PK icons", %{conn: conn, data_source: ds} do
      schema = catalog_schema_fixture(ds, %{name: "public"})
      table = catalog_table_fixture(ds, schema, %{name: "users"})

      catalog_column_fixture(ds, table, %{
        name: "id",
        data_type: "uuid",
        ordinal_position: 1,
        is_primary_key: true,
        is_nullable: false
      })

      catalog_column_fixture(ds, table, %{
        name: "email",
        data_type: "text",
        ordinal_position: 2,
        is_primary_key: false,
        is_nullable: false
      })

      {:ok, view, _html} = live(conn, ~p"/data-sources/#{ds.id}/catalog")
      view |> element("button", "public") |> render_click()
      html = view |> element("button", "users") |> render_click()

      assert html =~ "id"
      assert html =~ "uuid"
      assert html =~ "email"
      assert html =~ "text"
      assert html =~ "hero-key-micro"
    end

    test "has Sync button", %{conn: conn, data_source: ds} do
      {:ok, _view, html} = live(conn, ~p"/data-sources/#{ds.id}/catalog")
      assert html =~ "Sync Catalog"
    end
  end
end
