defmodule BeamFlowWeb.Admin.PostLive.EditorTest do
  use BeamFlowWeb.ConnCase
  import Phoenix.LiveViewTest

  alias BeamFlow.Accounts
  alias BeamFlow.Content

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "admin@example.com",
        password: "Password123!@#",
        name: "Test Admin",
        role: :admin
      })

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
  test "admin can access markdown editor for any post", %{conn: conn, user: user, post: post} do
    conn = log_in_user(conn, user)
    {:ok, view, _html} = live(conn, "/admin/posts/#{post.id}/edit")

    content = render(view)
    assert content =~ "markdown-editor"
  end
end
