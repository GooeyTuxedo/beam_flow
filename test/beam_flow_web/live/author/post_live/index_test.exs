defmodule BeamFlowWeb.Author.PostLive.IndexTest do
  use BeamFlowWeb.ConnCase
  import Phoenix.LiveViewTest

  alias BeamFlow.Accounts
  alias BeamFlow.Content

  setup do
    # Create a user with author role
    {:ok, user} =
      Accounts.register_user(%{
        email: "author@example.com",
        password: "Password123!@#",
        name: "Test Author",
        role: :author
      })

    # Create a post for this user
    {:ok, post} =
      Content.create_post(%{
        title: "Test Post",
        content: "Initial content",
        user_id: user.id,
        slug: "test-post",
        status: "draft"
      })

    %{user: user, post: post}
  end

  @tag :liveview
  test "markdown editor appears when editing post", %{conn: conn, user: user, post: post} do
    # Login the user (using the imported function from ConnCase)
    conn = log_in_user(conn, user)

    # Access the edit form
    {:ok, view, _html} = live(conn, "/author/posts/#{post.id}/edit")

    # Get the modal content
    modal_content = render(view)

    # Check for markdown editor
    assert modal_content =~ "markdown-editor"
    assert modal_content =~ "Content"

    # Check for toolbar buttons
    assert modal_content =~ "hero-bold"
    assert modal_content =~ "hero-link"
    assert modal_content =~ "hero-eye"

    # Check for preview area
    assert modal_content =~ "markdown-preview"
  end

  @tag :liveview
  test "markdown editor is visible in post form", %{conn: conn, user: user, post: post} do
    conn = log_in_user(conn, user)
    {:ok, view, _html} = live(conn, "/author/posts/#{post.id}/edit")

    # Simply verify the editor components are present
    modal_content = render(view)
    assert modal_content =~ "markdown-editor"
    # Button for bold text
    assert modal_content =~ "hero-bold"
    # Button for preview toggle
    assert modal_content =~ "hero-eye"
    # Preview area is present
    assert modal_content =~ "markdown-preview"
  end
end
