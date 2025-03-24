defmodule BeamFlowWeb.AdminRoutesTest do
  use BeamFlowWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import BeamFlow.AccountsFixtures

  setup do
    %{
      admin_user: user_fixture(%{role: :admin}),
      editor_user: user_fixture(%{role: :editor}),
      author_user: user_fixture(%{role: :author}),
      subscriber_user: user_fixture(%{role: :subscriber})
    }
  end

  describe "admin routes access" do
    @tag :liveview
    test "allows admin to access admin dashboard", %{conn: conn, admin_user: admin} do
      conn = log_in_user(conn, admin)

      {:ok, _view, html} = live(conn, "/admin")
      assert html =~ "Admin Dashboard"
    end

    @tag :liveview
    test "allows admin to access user management", %{conn: conn, admin_user: admin} do
      conn = log_in_user(conn, admin)

      {:ok, _view, html} = live(conn, "/admin/users")
      assert html =~ "Users"
    end

    @tag :liveview
    test "prevents non-admin from accessing admin routes", %{
      conn: conn,
      editor_user: editor,
      author_user: author,
      subscriber_user: subscriber
    } do
      for user <- [editor, author, subscriber] do
        conn = log_in_user(conn, user)

        assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/admin")
        assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/admin/users")
      end
    end

    @tag :liveview
    test "redirects to login for unauthenticated users", %{conn: conn} do
      assert {:error, {:redirect, %{to: path}}} = live(conn, "/admin")
      assert path =~ "/users/log_in"

      assert {:error, {:redirect, %{to: path}}} = live(conn, "/admin/users")
      assert path =~ "/users/log_in"
    end
  end

  describe "editor routes access" do
    @tag :liveview
    test "allows admin and editor to access editor dashboard", %{
      conn: conn,
      admin_user: admin,
      editor_user: editor
    } do
      for user <- [admin, editor] do
        conn = log_in_user(conn, user)

        {:ok, _view, html} = live(conn, "/editor")
        assert html =~ "Editor Dashboard"
      end
    end

    @tag :liveview
    test "prevents author and subscriber from accessing editor routes", %{
      conn: conn,
      author_user: author,
      subscriber_user: subscriber
    } do
      for user <- [author, subscriber] do
        conn = log_in_user(conn, user)

        assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/editor")
      end
    end
  end

  describe "author routes access" do
    @tag :liveview
    test "allows admin, editor, and author to access author dashboard", %{
      conn: conn,
      admin_user: admin,
      editor_user: editor,
      author_user: author
    } do
      for user <- [admin, editor, author] do
        conn = log_in_user(conn, user)

        {:ok, _view, html} = live(conn, "/author")
        assert html =~ "Author Dashboard"
      end
    end

    @tag :liveview
    test "prevents subscriber from accessing author routes", %{
      conn: conn,
      subscriber_user: subscriber
    } do
      conn = log_in_user(conn, subscriber)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/author")
    end
  end
end
