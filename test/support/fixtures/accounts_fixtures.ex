defmodule BeamFlow.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `BeamFlow.Accounts` context.
  """

  def unique_user_email, do: "user-#{System.unique_integer()}@example.com"
  def valid_user_password, do: "ValidPassword123!"
  def valid_user_name, do: "User #{System.unique_integer()}"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password(),
      name: valid_user_name()
    })
  end

  def user_fixture(attrs \\ %{}) do
    attrs = valid_user_attributes(attrs)

    {:ok, user} =
      attrs
      |> BeamFlow.Accounts.register_user(validate_password: false)

    user
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")

    [_prefix, token | _others] =
      String.split(captured_email.text_body || captured_email.body, "[TOKEN]")

    token
  end
end
