defmodule BeamFlow.Accounts.UserTokenTest do
  use BeamFlow.DataCase, async: true

  @moduletag :unit

  alias BeamFlow.Accounts.User
  alias BeamFlow.Accounts.UserToken
  alias BeamFlow.Repo

  setup do
    user =
      %User{
        id: 1,
        email: "test@example.com",
        name: "Test User",
        password_hash: "some_hash"
      }
      |> Repo.insert!()

    %{user: user}
  end

  describe "build_api_token/1" do
    @tag :unit
    test "generates a token for a user", %{user: user} do
      {token, user_token} = UserToken.build_api_token(user)

      assert is_binary(token)
      assert user_token.context == "api"
      assert user_token.user_id == user.id
      # Should be hashed
      assert user_token.token != token
      assert user_token.inserted_at
    end

    @tag :unit
    test "returns a URL-safe token", %{user: user} do
      {token, _user_token} = UserToken.build_api_token(user)

      assert String.match?(token, ~r/^[A-Za-z0-9_-]+$/)
    end
  end
end
