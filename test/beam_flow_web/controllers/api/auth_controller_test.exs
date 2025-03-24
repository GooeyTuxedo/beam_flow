defmodule BeamFlowWeb.API.AuthControllerTest do
  use BeamFlowWeb.ConnCase, async: true

  # Add integration tag to the module
  @moduletag :integration

  import BeamFlow.APITestHelpers

  alias BeamFlow.Accounts

  setup %{conn: conn} do
    user = create_user(:author)

    %{
      conn: conn,
      user: user,
      email: user.email,
      password: "Password123!"
    }
  end

  describe "create token" do
    @tag :integration
    test "returns token when credentials are valid", %{
      conn: conn,
      email: email,
      password: password
    } do
      response =
        conn
        |> api_request(:post, "/api/auth/token", %{email: email, password: password})
        |> json_response(201)

      assert response["token"]
      assert response["token_type"] == "Bearer"
      assert response["expires_in"] == 2_592_000
    end

    @tag :integration
    test "returns error when email is invalid", %{conn: conn, password: password} do
      response =
        conn
        |> api_request(:post, "/api/auth/token", %{email: "wrong@example.com", password: password})
        |> json_response(401)

      assert response["error"]["status"] == 401
      assert response["error"]["message"] == "Invalid email or password"
    end

    @tag :integration
    test "returns error when password is invalid", %{conn: conn, email: email} do
      response =
        conn
        |> api_request(:post, "/api/auth/token", %{email: email, password: "wrongpassword"})
        |> json_response(401)

      assert response["error"]["status"] == 401
      assert response["error"]["message"] == "Invalid email or password"
    end
  end

  describe "delete token" do
    @tag :integration
    test "revokes token successfully", %{conn: conn, user: user} do
      token = Accounts.generate_api_token(user)

      response =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete("/api/auth/token")
        |> response(:no_content)

      assert response == ""

      # Token should be revoked now
      assert token_is_revoked?(token)
    end

    @tag :integration
    test "returns error when no token is provided", %{conn: conn} do
      response =
        conn
        |> delete("/api/auth/token")
        |> json_response(401)

      assert response["error"]["status"] == 401
    end

    @tag :integration
    test "returns error when token is invalid", %{conn: conn} do
      response =
        conn
        |> put_req_header("authorization", "Bearer invalidtoken")
        |> delete("/api/auth/token")
        |> json_response(401)

      assert response["error"]["status"] == 401
    end
  end
end
