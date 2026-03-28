defmodule OnesqlxWeb.ErrorHTMLTest do
  use OnesqlxWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template, only: [render_to_string: 4]

  test "renders 404.html" do
    result = render_to_string(OnesqlxWeb.ErrorHTML, "404", "html", [])
    assert result =~ "Page Not Found"
    assert result =~ "Go to Dashboards"
  end

  test "renders 500.html" do
    result = render_to_string(OnesqlxWeb.ErrorHTML, "500", "html", [])
    assert result =~ "Something Went Wrong"
    assert result =~ "Go to Dashboards"
  end
end
