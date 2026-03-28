defmodule OnesqlxWeb.Plugs.ApiAuth do
  @moduledoc """
  Plug that authenticates API requests via Bearer tokens.

  Extracts the token from the `Authorization` header, verifies it,
  and assigns `current_scope` to the connection. Returns 401 JSON
  if authentication fails.
  """

  import Plug.Conn
  import Phoenix.Controller

  alias Onesqlx.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, scope} <- Accounts.get_scope_by_api_token(token) do
      assign(conn, :current_scope, scope)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{errors: %{detail: "Invalid or missing API token"}})
        |> halt()
    end
  end
end
