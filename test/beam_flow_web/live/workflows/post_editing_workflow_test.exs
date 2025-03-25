defmodule BeamFlowWeb.Workflows.PostEditingWorkflowTest do
  use BeamFlowWeb.ConnCase
  import Phoenix.LiveViewTest

  @tag :liveview
  @tag :user_journey
  test "author can create and edit post with markdown editor", %{conn: conn} do
    # Create an author and log in
    author = create_test_user("author")
    conn = log_in_user(conn, author)

    # Navigate to new post page
    {:ok, view, _html} = live(conn, "/author/posts/new")

    # Verify editor presence
    assert has_element?(view, "[phx-hook=MarkdownEditor]")

    # Create post with markdown content
    markdown_content = "# Test Heading\n\nThis is **bold** text."

    view
    |> form("#post-form", %{
      "post[title]" => "Test Markdown Post",
      "post[content]" => markdown_content,
      "post[status]" => "draft"
    })
    |> render_submit()

    # Get created post and verify content
    [post] = BeamFlow.Content.list_posts(search: "Test Markdown Post")
    assert post.content == markdown_content

    # Navigate to edit page
    {:ok, edit_view, _html} = live(conn, "/author/posts/#{post.id}/edit")
    rendered = render(edit_view)

    # Verify editor shows content and preview works
    assert rendered =~ "# Test Heading"
    assert rendered =~ "<h1>\nTest Heading</h1>"
    assert rendered =~ "<strong>bold</strong>"
  end

  @tag :integration
  @tag :user_journey
  test "complete post creation and publishing workflow", %{conn: conn} do
    # Setup users
    author = create_test_user("author")
    editor = create_test_user("editor")

    # Author creates post with markdown
    conn_author = log_in_user(conn, author)
    # Added _html
    {:ok, author_view, _html} = live(conn_author, "/author/posts/new")

    markdown_content = """
    # Workflow Test

    Testing **workflow** with:
    * Markdown formatting
    * Publishing process
    """

    author_view
    |> form("#post-form", %{
      "post[title]" => "Workflow Demo",
      "post[content]" => markdown_content,
      "post[status]" => "draft"
    })
    |> render_submit()

    # Get the created post
    [post] = BeamFlow.Content.list_posts(search: "Workflow Demo")

    # Editor edits the post
    conn_editor = log_in_user(build_conn(), editor)
    # Added _html
    {:ok, editor_edit_view, _html} = live(conn_editor, "/editor/posts/#{post.id}/edit")

    # Verify rendered markdown in editor
    assert render(editor_edit_view) =~ "Workflow Test"
    assert render(editor_edit_view) =~ "workflow"

    # Change status to published and save
    editor_edit_view
    |> form("#post-form", %{
      "post[status]" => "published"
    })
    |> render_submit()

    # Verify post was published
    updated_post = BeamFlow.Content.get_post!(post.id)
    assert updated_post.status == "published"
  end
end
