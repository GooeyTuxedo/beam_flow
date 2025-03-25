defmodule BeamFlowWeb.Editor.PostLive.EditorTest do
  use BeamFlowWeb.ConnCase
  import Phoenix.LiveViewTest

  alias BeamFlow.Accounts
  alias BeamFlow.Content

  setup do
    # Create editor user
    {:ok, editor} =
      Accounts.register_user(%{
        email: "editor@example.com",
        password: "Password123!@#",
        name: "Test Editor",
        role: :editor
      })

    # Create author user for testing editor's access to others' posts
    {:ok, author} =
      Accounts.register_user(%{
        email: "content.author@example.com",
        password: "Password123!@#",
        name: "Content Author",
        role: :author
      })

    # Create a post by the author
    {:ok, author_post} =
      Content.create_post(%{
        title: "Author's Post",
        content: "Author's content",
        user_id: author.id,
        slug: "author-post",
        status: "draft"
      })

    %{editor: editor, author: author, author_post: author_post}
  end

  @tag :liveview
  test "editor can access markdown editor for posts by other users", %{
    conn: conn,
    editor: editor,
    author_post: post
  } do
    conn = log_in_user(conn, editor)
    {:ok, view, _html} = live(conn, "/editor/posts/#{post.id}/edit")

    content = render(view)
    assert content =~ "markdown-editor"
  end
end
