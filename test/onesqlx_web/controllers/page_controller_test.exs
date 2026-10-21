defmodule OnesqlxWeb.PageControllerTest do
  use OnesqlxWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "SQL-first analytics platform"
  end

  test "homepage links to the product walkthrough", %{conn: conn} do
    document = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()

    assert document
           |> LazyHTML.query("#how-it-works-link")
           |> LazyHTML.attribute("href") == ["/how-it-works"]

    assert document
           |> LazyHTML.query("#public-how-it-works")
           |> LazyHTML.attribute("href") == ["/how-it-works"]
  end

  test "walkthrough is accessible without signing in", %{conn: conn} do
    document = conn |> get("/how-it-works") |> html_response(200) |> LazyHTML.from_document()

    assert document |> LazyHTML.query("#how-it-works-title") |> LazyHTML.text() ==
             "How OneSQLx works."

    assert document |> LazyHTML.query("#walkthrough-start") |> LazyHTML.attribute("href") ==
             ["/users/register"]
  end

  describe "signed in" do
    setup :register_and_log_in_user

    test "walkthrough opens the existing workspace", %{conn: conn} do
      document = conn |> get("/how-it-works") |> html_response(200) |> LazyHTML.from_document()

      assert document |> LazyHTML.query("#walkthrough-start") |> LazyHTML.attribute("href") ==
               ["/sql-editor"]
    end
  end
end
