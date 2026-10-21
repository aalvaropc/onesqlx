defmodule OnesqlxWeb.PageController do
  use OnesqlxWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def how_it_works(conn, _params) do
    render(conn, :how_it_works, page_title: "How it works")
  end
end
