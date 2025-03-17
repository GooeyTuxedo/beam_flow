defmodule BeamFlow.Accounts.UserNotifier do
  @moduledoc """
  This module is responsible for delivering notifications to users,
  such as confirmation emails or password reset instructions.

  In a production system, this would use Swoosh or another email delivery
  system, but for tests we'll use a simple implementation.
  """

  import Swoosh.Email

  # We don't need the Mailer for now since we're just returning the email
  # alias BeamFlow.Mailer

  # Delivers the email using the application mailer
  defp deliver(recipient, subject, body) do
    # Build the email structure
    _email =
      new()
      |> to(recipient)
      |> from({"BeamFlow CMS", "noreply@beamflow.example.com"})
      |> subject(subject)
      |> text_body(body)

    # For testing purposes, we'll just return the email
    # In production, we would call BeamFlow.Mailer.deliver(email)
    {:ok, %{to: recipient, subject: subject, body: body, text_body: body}}
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions", """

    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    deliver(user.email, "Reset password instructions", """

    ==============================

    Hi #{user.email},

    You can reset your password by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
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
end
