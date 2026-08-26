defmodule OnesqlxWeb.DataSourceLive.EditTest do
  use OnesqlxWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Onesqlx.DataSourcesFixtures

  alias Onesqlx.DataSources

  setup :register_and_log_in_user

  test "renders the form preloaded with current settings", %{conn: conn, scope: scope} do
    ds = data_source_fixture(scope, %{name: "prod-replica", statement_timeout_ms: 15_000})

    {:ok, _lv, html} = live(conn, ~p"/data-sources/#{ds.id}/edit")

    assert html =~ "Edit Data Source"
    assert html =~ "prod-replica"
    assert html =~ "15000"
    assert html =~ "leave blank to keep current"
  end

  test "updates limits without touching the password", %{conn: conn, scope: scope} do
    ds = data_source_fixture(scope)
    original_password = DataSources.decrypt_password(ds)

    {:ok, lv, _html} = live(conn, ~p"/data-sources/#{ds.id}/edit")

    lv
    |> form("#data-source-form",
      data_source: %{statement_timeout_ms: "60000", max_row_limit: "500", password: ""}
    )
    |> render_submit()

    assert_redirect(lv, ~p"/data-sources")

    updated = DataSources.get_data_source!(scope, ds.id)
    assert updated.statement_timeout_ms == 60_000
    assert updated.max_row_limit == 500
    assert DataSources.decrypt_password(updated) == original_password
  end

  test "shows validation errors", %{conn: conn, scope: scope} do
    ds = data_source_fixture(scope)

    {:ok, lv, _html} = live(conn, ~p"/data-sources/#{ds.id}/edit")

    html =
      lv
      |> form("#data-source-form", data_source: %{statement_timeout_ms: "10"})
      |> render_submit()

    assert html =~ "must be greater than or equal to 1000"
  end

  test "another workspace's data source is not reachable", %{conn: conn} do
    other_scope = Onesqlx.AccountsFixtures.user_scope_fixture()
    ds = data_source_fixture(other_scope)

    assert_raise Ecto.NoResultsError, fn ->
      live(conn, ~p"/data-sources/#{ds.id}/edit")
    end
  end
end
