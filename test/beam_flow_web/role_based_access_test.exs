defmodule BeamFlowWeb.RoleBasedAccessTest do
  use BeamFlowWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import BeamFlow.AccountsFixtures

  setup do
    # Create a set of users with different roles
    %{
      admin: user_fixture(%{role: :admin}),
      editor: user_fixture(%{role: :editor}),
      author: user_fixture(%{role: :author}),
      subscriber: user_fixture(%{role: :subscriber}),
      guest: nil
    }
  end

  describe "role-based dashboard access" do
    test "admin can access all dashboards", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin)

      # Admin dashboard
      {:ok, _view, html} = live(conn, ~p"/admin")
      assert html =~ "Admin Dashboard"

      # Editor dashboard
      {:ok, _view, html} = live(conn, ~p"/editor")
      assert html =~ "Editor Dashboard"

      # Author dashboard
      {:ok, _view, html} = live(conn, ~p"/author")
      assert html =~ "Author Dashboard"
    end

    test "editor can access editor and author dashboards", %{conn: conn, editor: editor} do
      conn = log_in_user(conn, editor)

      # Editor should not access admin dashboard
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin")

      # Editor dashboard
      {:ok, _view, html} = live(conn, ~p"/editor")
      assert html =~ "Editor Dashboard"

      # Author dashboard
      {:ok, _view, html} = live(conn, ~p"/author")
      assert html =~ "Author Dashboard"
    end

    test "author can only access author dashboard", %{conn: conn, author: author} do
      conn = log_in_user(conn, author)

      # Author should not access admin dashboard
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin")

      # Author should not access editor dashboard
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/editor")

      # Author dashboard
      {:ok, _view, html} = live(conn, ~p"/author")
      assert html =~ "Author Dashboard"
    end

    test "subscriber cannot access any dashboard", %{conn: conn, subscriber: subscriber} do
      conn = log_in_user(conn, subscriber)

      # Subscriber should not access admin dashboard
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin")

      # Subscriber should not access editor dashboard
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/editor")

      # Subscriber should not access author dashboard
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/author")
    end

    test "guest cannot access any dashboard", %{conn: conn} do
      # Guest should not access admin dashboard
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/admin")
      assert path =~ "/users/log_in"

      # Guest should not access editor dashboard
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/editor")
      assert path =~ "/users/log_in"

      # Guest should not access author dashboard
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/author")
      assert path =~ "/users/log_in"
    end
  end

  describe "admin features access" do
    test "only admin can access user management", %{conn: conn, admin: admin, editor: editor} do
      # Admin can access
      admin_conn = log_in_user(conn, admin)
      {:ok, _view, html} = live(admin_conn, ~p"/admin/users")
      assert html =~ "Users"

      # Editor cannot access
      editor_conn = log_in_user(conn, editor)
      assert {:error, {:redirect, %{to: "/"}}} = live(editor_conn, ~p"/admin/users")
    end

    test "role changes affect permissions immediately", %{conn: conn} do
      # Create a user with author role
      author = user_fixture(%{role: :author})
      conn = log_in_user(conn, author)

      # Verify initial access
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/editor")
      {:ok, _view, _html} = live(conn, ~p"/author")

      # Update the user role to editor
      {:ok, updated_user} =
        author
        |> Ecto.Changeset.change(%{role: :editor})
        |> BeamFlow.Repo.update()

      # Create a new session with the updated role
      new_conn =
        build_conn()
        |> log_in_user(updated_user)

      # Verify the new permissions take effect
      {:ok, _view, html} = live(new_conn, ~p"/editor")
      assert html =~ "Editor Dashboard"
    end
  end
end
