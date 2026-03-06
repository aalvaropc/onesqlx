defmodule OnesqlxWeb.PageController do
  use OnesqlxWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
