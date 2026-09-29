defmodule OnesqlxWeb.InvitationController do
  use OnesqlxWeb, :controller

  alias Onesqlx.Workspaces

  @doc """
  Accepts a workspace invitation by raw token.

  Requires authentication (the plug redirects to log in and returns here
  afterwards). A controller — not a LiveView — because on success the
  session's `:workspace_id` must switch to the joined workspace.
  """
  def accept(conn, %{"token" => token}) do
    user = conn.assigns.current_scope.user

    case Workspaces.accept_invitation(user, token) do
      {:ok, workspace} ->
        conn
        |> put_session(:workspace_id, workspace.id)
        |> put_flash(:info, "Welcome to #{workspace.name}!")
        |> redirect(to: ~p"/dashboards")

      {:error, :wrong_account} ->
        conn
        |> put_flash(
          :error,
          "This invitation was sent to a different email address. " <>
            "Log in with the invited account to accept it."
        )
        |> redirect(to: ~p"/dashboards")

      {:error, :invalid} ->
        conn
        |> put_flash(:error, "This invitation is invalid or has expired.")
        |> redirect(to: ~p"/dashboards")
    end
  end
end
