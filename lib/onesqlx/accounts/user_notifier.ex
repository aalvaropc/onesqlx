defmodule Onesqlx.Accounts.UserNotifier do
  @moduledoc """
  Delivers email notifications related to user accounts.
  """

  import Swoosh.Email

  alias Onesqlx.Accounts.User
  alias Onesqlx.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from(Onesqlx.MailerConfig.sender())
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Update email instructions", """

    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  @doc """
  Deliver a workspace invitation to an email address (the recipient may
  not have an account yet).
  """
  def deliver_workspace_invitation(email, workspace, invited_by, url) do
    deliver(email, "You've been invited to #{workspace.name} on OneSQLx", """

    ==============================

    Hi #{email},

    #{invited_by.email} invited you to join the "#{workspace.name}" workspace on OneSQLx.

    Accept the invitation by visiting the URL below:

    #{url}

    You'll need to sign in (or create an account) with this email address.
    The invitation expires in 7 days.

    If you weren't expecting this invitation, please ignore this email.

    ==============================
    """)
  end

  defp deliver_magic_link_instructions(user, url) do
    deliver(user.email, "Log in instructions", """

    ==============================

    Hi #{user.email},

    You can log into your account by visiting the URL below:

    #{url}

    If you didn't request this email, please ignore this.

    ==============================
    """)
  end

  defp deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions", """

    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end
end
