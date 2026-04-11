defmodule OnesqlxWeb.Plugs.RequireScope do
  @moduledoc """
  Plug that enforces API token scopes on endpoints.

  Returns 403 Forbidden if the token lacks the required scope.
  """

  import Plug.Conn
  import Phoenix.Controller

  def init(scope), do: scope

  def call(conn, required_scope) do
    scopes = conn.assigns[:api_scopes] || []

    if required_scope in scopes do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: %{code: "forbidden", message: "Token lacks '#{required_scope}' scope"}})
      |> halt()
    end
  end
end
