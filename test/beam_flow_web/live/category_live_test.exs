defmodule BeamFlowWeb.CategoryLiveTest do
  use BeamFlowWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias BeamFlow.Content

  @create_attrs %{name: "Technology", description: "Tech articles"}
  @update_attrs %{name: "Updated Category", description: "Updated description"}
  @invalid_attrs %{name: nil, description: nil}

  setup do
    # Create users with different roles
    admin = create_test_user("admin")
    editor = create_test_user("editor")
    author = create_test_user("author")

    # Create a test category
    {:ok, category} = Content.create_category(@create_attrs)

    {:ok, admin: admin, editor: editor, author: author, category: category}
  end

  describe "Index" do
    @tag :liveview
    test "lists all categories for admin", %{conn: conn, admin: admin, category: category} do
      {:ok, _index_live, html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/categories")

      assert html =~ "Categories"
      assert html =~ category.name
    end

    @tag :liveview
    test "lists all categories for editor", %{conn: conn, editor: editor, category: category} do
      {:ok, _index_live, html} =
        conn
        |> log_in_user(editor)
        |> live(~p"/editor/categories")

      assert html =~ "Categories"
      assert html =~ category.name
    end

    @tag :liveview
    test "redirects if author tries to access categories", %{conn: conn, author: author} do
      result =
        conn
        |> log_in_user(author)
        |> live(~p"/admin/categories")

      assert {:error,
              {:redirect,
               %{to: "/", flash: %{"error" => "You don't have permission to access this page."}}}} =
               result
    end

    @tag :liveview
    test "creates category as admin", %{conn: conn, admin: admin} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/categories")

      assert index_live |> element("a", "New Category") |> render_click() =~
               "New Category"

      assert_patch(index_live, ~p"/admin/categories/new")

      assert index_live
             |> form("#category-form", category: @invalid_attrs)
             |> render_submit() =~ "can&#39;t be blank"

      assert index_live
             |> form("#category-form", category: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/admin/categories")

      html = render(index_live)
      assert html =~ "Category created successfully"
      assert html =~ "Technology"
    end

    @tag :liveview
    test "updates category as editor", %{conn: conn, editor: editor, category: category} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(editor)
        |> live(~p"/editor/categories")

      assert index_live |> element("a", "Edit") |> render_click() =~
               "Edit Category"

      assert_patch(index_live, ~p"/editor/categories/#{category}/edit")

      assert index_live
             |> form("#category-form", category: @invalid_attrs)
             |> render_submit() =~ "can&#39;t be blank"

      assert index_live
             |> form("#category-form", category: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/editor/categories")

      html = render(index_live)
      assert html =~ "Category updated successfully"
      assert html =~ "Updated Category"
    end

    @tag :liveview
    test "deletes category in listing", %{conn: conn, admin: admin, category: category} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/categories")

      assert index_live |> element("a", "Delete") |> render_click()
      refute has_element?(index_live, "#category-#{category.id}")
    end
  end
end
