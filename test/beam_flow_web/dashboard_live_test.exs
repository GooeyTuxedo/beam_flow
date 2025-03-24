defmodule BeamFlowWeb.DashboardLiveTest do
  use BeamFlowWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import BeamFlow.AccountsFixtures

  describe "Admin Dashboard" do
    setup [:create_user_and_log_in_as_admin]

    @tag :liveview
    test "renders dashboard elements", %{conn: conn} do
      {:ok, view, html} = live(conn, "/admin")

      # Test that dashboard shows the expected sections
      assert html =~ "Admin Dashboard"
      assert has_element?(view, "h3", "Recent Activity")

      # Test dashboard cards
      assert has_element?(view, "[data-test-id='dashboard-card']", "Users")
      assert has_element?(view, "[data-test-id='dashboard-card']", "Posts")
      assert has_element?(view, "[data-test-id='dashboard-card']", "Comments")

      # Test navigation links
      assert has_element?(view, "a", "New User")
      # Check that the link exists and has the right destination
      assert view |> element("a", "New User") |> render() =~ "/admin/users/new"
    end
  end

  describe "Editor Dashboard" do
    setup [:create_user_and_log_in_as_editor]

    @tag :liveview
    test "renders dashboard elements", %{conn: conn} do
      {:ok, view, html} = live(conn, "/editor")

      # Test that dashboard shows the expected sections
      assert html =~ "Editor Dashboard"
      assert has_element?(view, "h3", "Pending Approvals")

      # Test dashboard cards
      assert has_element?(view, "[data-test-id='dashboard-card']", "Posts")
      assert has_element?(view, "[data-test-id='dashboard-card']", "Comments")
      assert has_element?(view, "[data-test-id='dashboard-card']", "Media")
    end
  end

  describe "Author Dashboard" do
    setup [:create_user_and_log_in_as_author]

    @tag :liveview
    test "renders dashboard elements", %{conn: conn} do
      {:ok, view, html} = live(conn, "/author")

      # Test that dashboard shows the expected sections
      assert html =~ "Author Dashboard"
      assert has_element?(view, "h3", "Recent Posts")

      # Test dashboard cards
      assert has_element?(view, "[data-test-id='dashboard-card']", "My Posts")
      assert has_element?(view, "[data-test-id='dashboard-card']", "Drafts")
      assert has_element?(view, "[data-test-id='dashboard-card']", "Comments")

      # Test navigation links
      assert has_element?(view, "a", "New Post")
      # Check that the link exists and has the right destination
      assert view |> element("a", "New Post") |> render() =~ "/author/posts/new"
    end
  end

  # Test helpers

  defp create_user_and_log_in_as_admin(%{conn: conn}) do
    admin = user_fixture(%{role: :admin})
    %{conn: log_in_user(conn, admin), user: admin}
  end

  defp create_user_and_log_in_as_editor(%{conn: conn}) do
    editor = user_fixture(%{role: :editor})
    %{conn: log_in_user(conn, editor), user: editor}
  end

  defp create_user_and_log_in_as_author(%{conn: conn}) do
    author = user_fixture(%{role: :author})
    %{conn: log_in_user(conn, author), user: author}
  end
end
