defmodule BeamFlowWeb.Shared.PostLive.FormComponentTest do
  use BeamFlowWeb.ConnCase
  import Phoenix.LiveViewTest

  alias BeamFlow.Content.Post
  alias BeamFlowWeb.Shared.PostLive.FormComponent

  setup do
    user = %BeamFlow.Accounts.User{id: 1, email: "test@example.com", name: "Test User"}

    post = %Post{
      id: 1,
      title: "Test Post",
      content: "Initial content",
      user_id: user.id,
      slug: "test-post"
    }

    %{post: post, user: user}
  end

  @tag :integration
  test "renders markdown editor", %{post: post, user: user} do
    html =
      render_component(FormComponent, %{
        id: "test-form",
        action: :edit,
        post: post,
        current_user: user,
        title: "Edit Post",
        return_to: "/admin/posts"
      })

    # Component structure checks
    assert html =~ "markdown-editor"
    assert html =~ "markdown-input"
    assert html =~ "markdown-preview"
  end

  @tag :integration
  test "includes formatting toolbar", %{post: post, user: user} do
    html =
      render_component(FormComponent, %{
        id: "test-form",
        action: :edit,
        post: post,
        current_user: user,
        title: "Edit Post",
        return_to: "/admin/posts"
      })

    # Check toolbar buttons
    assert html =~ "hero-bold"
    assert html =~ "hero-link"
    assert html =~ "hero-photo"
    assert html =~ "hero-list-bullet"
    assert html =~ "hero-eye"
  end
end
