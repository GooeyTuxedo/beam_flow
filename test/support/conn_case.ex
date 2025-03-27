defmodule BeamFlowWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use BeamFlowWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint BeamFlowWeb.Endpoint

      use BeamFlowWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import BeamFlowWeb.ConnCase
    end
  end

  setup tags do
    BeamFlow.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Setup helper that registers and logs in users.

      setup :register_and_log_in_user

  It stores an updated connection and a registered user in the
  test context.
  """
  def register_and_log_in_user(%{conn: conn}) do
    user = BeamFlow.AccountsFixtures.user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  @doc """
  Logs the given `user` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_user(conn, user) do
    token = BeamFlow.Accounts.generate_user_session_token(user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  @doc """
  Creates a test user with the specified role.
  """
  def create_test_user(role) do
    {:ok, user} =
      BeamFlow.Accounts.register_user(%{
        email: "#{role}_#{:rand.uniform(1000)}@example.com",
        password: "Password123!@#",
        name: "Test #{String.capitalize(role)}",
        role: String.to_existing_atom(role)
      })

    user
  end

  @doc """
  Creates a test media file associated with the given user.
  """
  def create_test_media(user, attrs \\ %{}) do
    default_attrs = %{
      filename: "test-#{System.unique_integer()}.jpg",
      original_filename: "test.jpg",
      content_type: "image/jpeg",
      path: "/uploads/test-#{System.unique_integer()}.jpg",
      size: 1024,
      user_id: user.id
    }

    merged_attrs = Map.merge(default_attrs, attrs)

    {:ok, media} = BeamFlow.Repo.insert(struct(BeamFlow.Content.Media, merged_attrs))
    media
  end
end
