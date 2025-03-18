defmodule BeamFlowWeb.LiveAuthTest do
  use BeamFlowWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import BeamFlow.AccountsFixtures

  alias BeamFlow.Accounts
  alias BeamFlowWeb.LiveAuth

  describe "on_mount callbacks" do
    test "ensure_authenticated blocks unauthenticated access", %{conn: _conn} do
      # Create a mock socket
      socket = %Phoenix.LiveView.Socket{
        endpoint: BeamFlowWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      # No session, should halt
      result = LiveAuth.on_mount(:ensure_authenticated, %{}, %{}, socket)
      assert {:halt, %{assigns: %{flash: %{"error" => message}}}} = result
      assert message == "You must log in to access this page."

      # With invalid token, should halt
      result = LiveAuth.on_mount(:ensure_authenticated, %{}, %{"user_token" => "invalid"}, socket)
      assert {:halt, %{assigns: %{flash: %{"error" => message}}}} = result
      assert message == "You must log in to access this page."

      # With valid token, should continue
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)

      result = LiveAuth.on_mount(:ensure_authenticated, %{}, %{"user_token" => token}, socket)
      assert {:cont, %{assigns: %{current_user: %{id: id}}}} = result
      assert id == user.id
    end

    test "ensure_role blocks insufficient privileges", %{conn: _conn} do
      # Create a mock socket
      socket = %Phoenix.LiveView.Socket{
        endpoint: BeamFlowWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      # Create users with different roles
      admin = user_fixture(%{role: :admin})
      editor = user_fixture(%{role: :editor})
      author = user_fixture(%{role: :author})
      subscriber = user_fixture(%{role: :subscriber})

      admin_token = Accounts.generate_user_session_token(admin)
      editor_token = Accounts.generate_user_session_token(editor)
      author_token = Accounts.generate_user_session_token(author)
      subscriber_token = Accounts.generate_user_session_token(subscriber)

      # Test admin privileges
      result =
        LiveAuth.on_mount({:ensure_role, :admin}, %{}, %{"user_token" => admin_token}, socket)

      assert {:cont, %{assigns: %{current_user: %{id: id}}}} = result
      assert id == admin.id

      result =
        LiveAuth.on_mount({:ensure_role, :admin}, %{}, %{"user_token" => editor_token}, socket)

      assert {:halt, %{assigns: %{flash: %{"error" => message}}}} = result
      assert message == "You don't have permission to access this page."

      # Test editor privileges
      result =
        LiveAuth.on_mount({:ensure_role, :editor}, %{}, %{"user_token" => admin_token}, socket)

      assert {:cont, %{assigns: %{current_user: %{id: id}}}} = result
      assert id == admin.id

      result =
        LiveAuth.on_mount({:ensure_role, :editor}, %{}, %{"user_token" => editor_token}, socket)

      assert {:cont, %{assigns: %{current_user: %{id: id}}}} = result
      assert id == editor.id

      result =
        LiveAuth.on_mount({:ensure_role, :editor}, %{}, %{"user_token" => author_token}, socket)

      assert {:halt, %{assigns: %{flash: %{"error" => message}}}} = result
      assert message == "You don't have permission to access this page."

      # Test author privileges
      result =
        LiveAuth.on_mount({:ensure_role, :author}, %{}, %{"user_token" => admin_token}, socket)

      assert {:cont, %{assigns: %{current_user: %{id: id}}}} = result
      assert id == admin.id

      result =
        LiveAuth.on_mount({:ensure_role, :author}, %{}, %{"user_token" => editor_token}, socket)

      assert {:cont, %{assigns: %{current_user: %{id: id}}}} = result
      assert id == editor.id

      result =
        LiveAuth.on_mount({:ensure_role, :author}, %{}, %{"user_token" => author_token}, socket)

      assert {:cont, %{assigns: %{current_user: %{id: id}}}} = result
      assert id == author.id

      result =
        LiveAuth.on_mount(
          {:ensure_role, :author},
          %{},
          %{"user_token" => subscriber_token},
          socket
        )

      assert {:halt, %{assigns: %{flash: %{"error" => message}}}} = result
      assert message == "You don't have permission to access this page."
    end

    test "assign_user_roles adds role information to socket", %{conn: _conn} do
      admin = user_fixture(%{role: :admin})

      socket = %Phoenix.LiveView.Socket{
        endpoint: BeamFlowWeb.Endpoint,
        assigns: %{current_user: admin, __changed__: %{}}
      }

      updated_socket = LiveAuth.assign_user_roles(socket)

      assert updated_socket.assigns.user_roles
      assert updated_socket.assigns.is_admin
      assert updated_socket.assigns.is_editor
      assert updated_socket.assigns.is_author

      # Test with different role
      author = user_fixture(%{role: :author})

      socket = %Phoenix.LiveView.Socket{
        endpoint: BeamFlowWeb.Endpoint,
        assigns: %{current_user: author, __changed__: %{}}
      }

      updated_socket = LiveAuth.assign_user_roles(socket)

      assert updated_socket.assigns.user_roles
      refute updated_socket.assigns.is_admin
      refute updated_socket.assigns.is_editor
      assert updated_socket.assigns.is_author

      # Test with no user
      socket = %Phoenix.LiveView.Socket{
        endpoint: BeamFlowWeb.Endpoint,
        assigns: %{__changed__: %{}}
      }

      updated_socket = LiveAuth.assign_user_roles(socket)

      assert updated_socket.assigns.user_roles == []
      refute updated_socket.assigns.is_admin
      refute updated_socket.assigns.is_editor
      refute updated_socket.assigns.is_author
    end

    test "redirect_if_authenticated redirects logged in users", %{conn: _conn} do
      # Create a mock socket
      socket = %Phoenix.LiveView.Socket{
        endpoint: BeamFlowWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      # With no session, should continue
      result = LiveAuth.on_mount(:redirect_if_authenticated, %{}, %{}, socket)
      assert {:cont, %{assigns: %{current_user: nil}}} = result

      # With valid token, should redirect
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)

      result =
        LiveAuth.on_mount(:redirect_if_authenticated, %{}, %{"user_token" => token}, socket)

      assert {:halt, redirect_socket} = result
      assert %Phoenix.LiveView.Socket{redirected: {:redirect, %{to: "/"}}} = redirect_socket
    end
  end

  describe "LiveAuth in LiveView controllers" do
    test "on_mount assigns current user", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      # Visit a LiveView page - we'll use the settings page for this test
      {:ok, live_view, _html} = live(conn, ~p"/users/settings")

      # Extract assigns from the rendered HTML instead of directly accessing view.assigns
      html = render(live_view)
      assert html =~ user.email
    end

    test "ensure_authenticated redirects when not logged in", %{conn: conn} do
      # Try to visit a protected LiveView
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/users/settings")
      assert path =~ "/users/log_in"
    end
  end
end
