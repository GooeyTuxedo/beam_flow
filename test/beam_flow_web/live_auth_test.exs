defmodule BeamFlowWeb.LiveAuthTest do
  use BeamFlowWeb.ConnCase, async: true

  import BeamFlow.AccountsFixtures

  alias BeamFlowWeb.LiveAuth
  alias Phoenix.LiveView.Socket

  # Setup test users with different roles
  setup do
    %{
      admin_user: user_fixture(%{role: :admin}),
      editor_user: user_fixture(%{role: :editor}),
      author_user: user_fixture(%{role: :author}),
      subscriber_user: user_fixture(%{role: :subscriber})
    }
  end

  describe "on_mount/4 with :ensure_admin" do
    test "allows admins", %{admin_user: admin} do
      token = BeamFlow.Accounts.generate_user_session_token(admin)
      socket = %Socket{endpoint: BeamFlowWeb.Endpoint, assigns: %{__changed__: %{}}}

      assert {:cont, %{assigns: %{current_user: %{id: user_id}}}} =
               LiveAuth.on_mount(:ensure_admin, %{}, %{"user_token" => token}, socket)

      assert user_id == admin.id
    end

    test "rejects non-admin roles", %{
      editor_user: editor,
      author_user: author,
      subscriber_user: subscriber
    } do
      for user <- [editor, author, subscriber] do
        token = BeamFlow.Accounts.generate_user_session_token(user)

        socket = %Socket{
          endpoint: BeamFlowWeb.Endpoint,
          assigns: %{__changed__: %{}, flash: %{}}
        }

        assert {:halt, %{assigns: %{current_user: %{id: user_id}}}} =
                 LiveAuth.on_mount(:ensure_admin, %{}, %{"user_token" => token}, socket)

        assert user_id == user.id
      end
    end

    test "rejects unauthenticated users" do
      socket = %Socket{
        endpoint: BeamFlowWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      assert {:halt, _socket} =
               LiveAuth.on_mount(:ensure_admin, %{}, %{}, socket)
    end
  end

  describe "on_mount/4 with :ensure_editor" do
    test "allows admins and editors", %{admin_user: admin, editor_user: editor} do
      for user <- [admin, editor] do
        token = BeamFlow.Accounts.generate_user_session_token(user)
        socket = %Socket{endpoint: BeamFlowWeb.Endpoint, assigns: %{__changed__: %{}}}

        assert {:cont, %{assigns: %{current_user: %{id: user_id}}}} =
                 LiveAuth.on_mount(:ensure_editor, %{}, %{"user_token" => token}, socket)

        assert user_id == user.id
      end
    end

    test "rejects author and subscriber roles", %{
      author_user: author,
      subscriber_user: subscriber
    } do
      for user <- [author, subscriber] do
        token = BeamFlow.Accounts.generate_user_session_token(user)

        socket = %Socket{
          endpoint: BeamFlowWeb.Endpoint,
          assigns: %{__changed__: %{}, flash: %{}}
        }

        assert {:halt, %{assigns: %{current_user: %{id: user_id}}}} =
                 LiveAuth.on_mount(:ensure_editor, %{}, %{"user_token" => token}, socket)

        assert user_id == user.id
      end
    end
  end

  describe "on_mount/4 with :ensure_author" do
    test "allows admins, editors, and authors", %{
      admin_user: admin,
      editor_user: editor,
      author_user: author
    } do
      for user <- [admin, editor, author] do
        token = BeamFlow.Accounts.generate_user_session_token(user)
        socket = %Socket{endpoint: BeamFlowWeb.Endpoint, assigns: %{__changed__: %{}}}

        assert {:cont, %{assigns: %{current_user: %{id: user_id}}}} =
                 LiveAuth.on_mount(:ensure_author, %{}, %{"user_token" => token}, socket)

        assert user_id == user.id
      end
    end

    test "rejects subscriber role", %{subscriber_user: subscriber} do
      token = BeamFlow.Accounts.generate_user_session_token(subscriber)

      socket = %Socket{
        endpoint: BeamFlowWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      assert {:halt, %{assigns: %{current_user: %{id: user_id}}}} =
               LiveAuth.on_mount(:ensure_author, %{}, %{"user_token" => token}, socket)

      assert user_id == subscriber.id
    end
  end

  describe "on_mount/4 with :audit_access" do
    test "logs user access", %{admin_user: admin} do
      token = BeamFlow.Accounts.generate_user_session_token(admin)
      socket = %Socket{endpoint: BeamFlowWeb.Endpoint, assigns: %{__changed__: %{path: "/admin"}}}
      params = %{"section" => "admin"}

      assert {:cont, %{assigns: %{current_user: %{id: user_id}}}} =
               LiveAuth.on_mount(:audit_access, params, %{"user_token" => token}, socket)

      assert user_id == admin.id

      # Verify that an audit log was created
      logs = BeamFlow.Accounts.list_user_logs(admin.id)
      assert length(logs) > 0

      # Get the most recent log
      [latest_log | _rest] = logs
      assert latest_log.action == "access:admin"
      assert latest_log.user_id == admin.id
      assert latest_log.metadata["path"] == "/admin"
    end
  end

  describe "on_mount/4 with {:ensure_role, role}" do
    test "allows users with the specified role or higher", %{
      admin_user: admin,
      editor_user: editor
    } do
      token = BeamFlow.Accounts.generate_user_session_token(editor)
      socket = %Socket{endpoint: BeamFlowWeb.Endpoint, assigns: %{__changed__: %{}}}

      # Admin can access editor role
      admin_token = BeamFlow.Accounts.generate_user_session_token(admin)

      assert {:cont, _socket} =
               LiveAuth.on_mount(
                 {:ensure_role, :editor},
                 %{},
                 %{"user_token" => admin_token},
                 socket
               )

      # Editor can access editor role
      assert {:cont, _socket} =
               LiveAuth.on_mount({:ensure_role, :editor}, %{}, %{"user_token" => token}, socket)
    end

    test "rejects users with lower roles", %{author_user: author, subscriber_user: subscriber} do
      socket = %Socket{
        endpoint: BeamFlowWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      # Author trying to access editor role
      author_token = BeamFlow.Accounts.generate_user_session_token(author)

      assert {:halt, _socket} =
               LiveAuth.on_mount(
                 {:ensure_role, :editor},
                 %{},
                 %{"user_token" => author_token},
                 socket
               )

      # Subscriber trying to access author role
      subscriber_token = BeamFlow.Accounts.generate_user_session_token(subscriber)

      assert {:halt, _socket} =
               LiveAuth.on_mount(
                 {:ensure_role, :author},
                 %{},
                 %{"user_token" => subscriber_token},
                 socket
               )
    end
  end
end
