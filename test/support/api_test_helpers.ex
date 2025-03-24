# Create file: test/support/api_test_helpers.ex

defmodule BeamFlow.APITestHelpers do
  @moduledoc """
  Helper functions for API testing.
  """

  import Plug.Conn
  import Phoenix.ConnTest

  alias BeamFlow.Accounts
  alias BeamFlow.Content

  @endpoint BeamFlowWeb.Endpoint

  @doc """
  Creates a user with the given role and returns the user.
  """
  def create_user(role \\ :subscriber) do
    email = "test-#{System.unique_integer([:positive])}@example.com"

    {:ok, user} =
      Accounts.register_user(%{
        email: email,
        name: "Test User",
        password: "Password123!",
        role: role
      })

    # Skip confirmation - just return user with confirmed_at set
    # Fix: truncate to seconds to avoid precision issues
    {:ok, confirmed_user} =
      user
      |> Ecto.Changeset.change(
        confirmed_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      )
      |> BeamFlow.Repo.update()

    confirmed_user
  end

  @doc """
  Creates a post for the given user and returns the post.
  """
  def create_post(user, attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        title: "Test Post #{System.unique_integer([:positive])}",
        content: "Test content for the post",
        status: "draft"
      })
      |> Map.put(:user_id, user.id)

    {:ok, post} = Content.create_post(attrs)
    post
  end

  @doc """
  Makes an authenticated API request.
  """
  def api_request(conn, method, path, body \\ %{}, user \\ nil) do
    conn = %{conn | host: "localhost", request_path: path}

    conn =
      if user do
        token = Accounts.generate_api_token(user)
        conn |> put_req_header("authorization", "Bearer #{token}")
      else
        conn
      end

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")

    case method do
      :get -> get(conn, path)
      :post -> post(conn, path, Jason.encode!(body))
      :put -> put(conn, path, Jason.encode!(body))
      :patch -> patch(conn, path, Jason.encode!(body))
      :delete -> delete(conn, path)
    end
  end

  @doc """
  Checks if a token has been revoked, returns true if revoked
  """
  def token_is_revoked?(token) do
    Accounts.get_user_by_api_token(token) == nil
  end
end
