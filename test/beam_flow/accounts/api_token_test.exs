defmodule BeamFlow.Accounts.APITokenTest do
  use BeamFlow.DataCase, async: true

  @moduletag :unit

  alias BeamFlow.Accounts
  alias BeamFlow.Accounts.User
  alias BeamFlow.Accounts.UserToken
  alias BeamFlow.Repo

  setup do
    user =
      %User{
        id: 1,
        email: "api-token-test@example.com",
        name: "API Test User",
        password_hash: "some_hash"
      }
      |> Repo.insert!()

    %{user: user}
  end

  describe "generate_api_token/1" do
    @tag :unit
    test "creates a token and stores it in the database", %{user: user} do
      token = Accounts.generate_api_token(user)

      assert is_binary(token)

      # Verify token exists in DB
      db_token_count = Enum.count(Repo.all(UserToken))

      assert db_token_count > 0
    end
  end

  # Rest of the test remains the same
  describe "get_user_by_api_token/1" do
    @tag :unit
    test "returns the user for a valid token", %{user: user} do
      token = Accounts.generate_api_token(user)

      found_user = Accounts.get_user_by_api_token(token)

      assert found_user
      assert found_user.id == user.id
    end

    @tag :unit
    test "returns nil for an invalid token" do
      assert Accounts.get_user_by_api_token("invalid_token") == nil
    end

    @tag :unit
    test "returns nil for a malformed token" do
      assert Accounts.get_user_by_api_token("not-base64!") == nil
    end
  end

  describe "revoke_api_token/1" do
    @tag :unit
    test "revokes a valid token", %{user: user} do
      token = Accounts.generate_api_token(user)

      # Verify token works
      assert Accounts.get_user_by_api_token(token)

      # Revoke token
      assert Accounts.revoke_api_token(token) == :ok

      # Verify token no longer works
      assert Accounts.get_user_by_api_token(token) == nil
    end

    @tag :unit
    test "returns error for invalid token" do
      assert Accounts.revoke_api_token("invalid_token") == :error
    end
  end
end
