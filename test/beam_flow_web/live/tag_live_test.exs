defmodule BeamFlowWeb.TagLiveTest do
  use BeamFlowWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias BeamFlow.Content

  @create_attrs %{name: "Elixir"}
  @update_attrs %{name: "Updated Tag"}
  @invalid_attrs %{name: nil}

  setup do
    # Create users with different roles
    admin = create_test_user("admin")
    editor = create_test_user("editor")
    author = create_test_user("author")

    # Create a test tag
    {:ok, tag} = Content.create_tag(@create_attrs)

    {:ok, admin: admin, editor: editor, author: author, tag: tag}
  end

  describe "Index" do
    @tag :liveview
    test "lists all tags for admin", %{conn: conn, admin: admin, tag: tag} do
      {:ok, _index_live, html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/tags")

      assert html =~ "Tags"
      assert html =~ tag.name
    end

    @tag :liveview
    test "lists all tags for editor", %{conn: conn, editor: editor, tag: tag} do
      {:ok, _index_live, html} =
        conn
        |> log_in_user(editor)
        |> live(~p"/editor/tags")

      assert html =~ "Tags"
      assert html =~ tag.name
    end

    @tag :liveview
    test "redirects if author tries to access tags", %{conn: conn, author: author} do
      result =
        conn
        |> log_in_user(author)
        |> live(~p"/admin/tags")

      assert {:error,
              {:redirect,
               %{to: "/", flash: %{"error" => "You don't have permission to access this page."}}}} =
               result
    end

    @tag :liveview
    test "creates tag as admin", %{conn: conn, admin: admin} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/tags")

      assert index_live |> element("a", "New Tag") |> render_click() =~
               "New Tag"

      assert_patch(index_live, ~p"/admin/tags/new")

      assert index_live
             |> form("#tag-form", tag: @invalid_attrs)
             |> render_submit() =~ "can&#39;t be blank"

      assert index_live
             |> form("#tag-form", tag: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/admin/tags")

      html = render(index_live)
      assert html =~ "Tag created successfully"
      assert html =~ "Elixir"
    end

    @tag :liveview
    test "updates tag as editor", %{conn: conn, editor: editor, tag: tag} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(editor)
        |> live(~p"/editor/tags")

      assert index_live |> element("a", "Edit") |> render_click() =~
               "Edit Tag"

      assert_patch(index_live, ~p"/editor/tags/#{tag}/edit")

      assert index_live
             |> form("#tag-form", tag: @invalid_attrs)
             |> render_submit() =~ "can&#39;t be blank"

      assert index_live
             |> form("#tag-form", tag: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/editor/tags")

      html = render(index_live)
      assert html =~ "Tag updated successfully"
      assert html =~ "Updated Tag"
    end

    @tag :liveview
    test "deletes tag in listing", %{conn: conn, admin: admin, tag: tag} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/tags")

      assert index_live |> element("a", "Delete") |> render_click()
      refute has_element?(index_live, "#tag-#{tag.id}")
    end
  end
end
