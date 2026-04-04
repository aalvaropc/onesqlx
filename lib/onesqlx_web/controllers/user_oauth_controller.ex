defmodule OnesqlxWeb.UserOAuthController do
  @moduledoc """
  Handles OAuth2 callbacks from Google and GitHub via Ueberauth.

  Creates a new user+workspace if the email doesn't exist, or logs in
  the existing user if it does. OAuth users are auto-confirmed.
  """

  use OnesqlxWeb, :controller

  alias Onesqlx.Accounts

  plug Ueberauth

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    email = auth.info.email

    case find_or_create_user(email) do
      {:ok, user} ->
        OnesqlxWeb.UserAuth.log_in_user(conn, user)

      {:error, reason} ->
        conn
        |> put_flash(:error, "Authentication failed: #{inspect(reason)}")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  def callback(%{assigns: %{ueberauth_failure: _failure}} = conn, _params) do
    conn
    |> put_flash(:error, "Authentication failed. Please try again.")
    |> redirect(to: ~p"/users/log-in")
  end

  def request(conn, _params) do
    # Ueberauth handles the redirect automatically via the plug
    # This clause is a fallback for unsupported providers
    conn
    |> put_flash(:error, "Unsupported authentication provider.")
    |> redirect(to: ~p"/users/log-in")
  end

  defp find_or_create_user(email) when is_binary(email) do
    case Accounts.get_user_by_email(email) do
      nil ->
        with {:ok, user} <- Accounts.register_user(%{email: email}) do
          Accounts.confirm_user_from_oauth(user)
        end

      user ->
        {:ok, user}
    end
  end

  defp find_or_create_user(_), do: {:error, :no_email}
end
