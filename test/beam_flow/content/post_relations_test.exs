defmodule BeamFlow.Content.PostRelationsTest do
  use BeamFlow.DataCase, async: true
  import BeamFlowWeb.ConnCase, only: [create_test_user: 1]
  alias BeamFlow.Content
  alias BeamFlow.Content.Post

  setup do
    # Create test user
    user = create_test_user("author")

    # Create categories
    {:ok, category1} = Content.create_category(%{name: "Technology"})
    {:ok, category2} = Content.create_category(%{name: "Elixir"})

    # Create tags
    {:ok, tag1} = Content.create_tag(%{name: "Programming"})
    {:ok, tag2} = Content.create_tag(%{name: "Web"})

    {:ok, user: user, categories: [category1, category2], tags: [tag1, tag2]}
  end

  describe "post with categories and tags" do
    @tag :integration
    @tag :post_relations
    test "creates post with categories and tags", %{
      user: user,
      categories: [category1, category2],
      tags: [tag1, tag2]
    } do
      attrs = %{
        title: "Test Post",
        content: "Content",
        status: "draft",
        user_id: user.id,
        category_ids: [category1.id, category2.id],
        tag_ids: [tag1.id, tag2.id]
      }

      assert {:ok, %Post{} = post} = Content.create_post(attrs)

      # Reload post with associations
      post = Content.get_post!(post.id)

      # Verify associations
      assert length(post.categories) == 2
      assert length(post.tags) == 2

      category_ids = Enum.map(post.categories, & &1.id)
      assert category1.id in category_ids
      assert category2.id in category_ids

      tag_ids = Enum.map(post.tags, & &1.id)
      assert tag1.id in tag_ids
      assert tag2.id in tag_ids
    end

    @tag :integration
    @tag :post_relations
    test "updates post categories and tags", %{
      user: user,
      categories: [category1, category2],
      tags: [tag1, tag2]
    } do
      # Create post with initial categories/tags
      {:ok, post} =
        Content.create_post(%{
          title: "Initial Post",
          content: "Content",
          status: "draft",
          user_id: user.id,
          category_ids: [category1.id],
          tag_ids: [tag1.id]
        })

      # Update with new categories/tags
      {:ok, updated_post} =
        Content.update_post(post, %{
          category_ids: [category2.id],
          tag_ids: [tag1.id, tag2.id]
        })

      # Verify associations
      updated_post = Content.get_post!(updated_post.id)

      assert length(updated_post.categories) == 1
      assert hd(updated_post.categories).id == category2.id

      assert length(updated_post.tags) == 2
      tag_ids = Enum.map(updated_post.tags, & &1.id)
      assert tag1.id in tag_ids
      assert tag2.id in tag_ids
    end

    @tag :integration
    @tag :post_relations
    @tag :cascading
    test "deleting a category removes it from posts", %{
      user: user,
      categories: [category1, _],
      tags: [tag1, _]
    } do
      # Create post with category
      {:ok, post} =
        Content.create_post(%{
          title: "Category Test",
          content: "Content",
          status: "draft",
          user_id: user.id,
          category_ids: [category1.id],
          tag_ids: [tag1.id]
        })

      # Verify category association
      post = Content.get_post!(post.id)
      assert length(post.categories) == 1

      # Delete the category
      Content.delete_category(category1)

      # Verify post no longer has the category
      updated_post = Content.get_post!(post.id)
      assert updated_post.categories == []
      assert length(updated_post.tags) == 1
    end

    @tag :integration
    @tag :post_relations
    @tag :querying
    test "listing posts by category", %{
      user: user,
      categories: [category1, category2],
      tags: [tag1, _]
    } do
      # Create posts with different categories
      {:ok, post1} =
        Content.create_post(%{
          title: "Post One",
          content: "Content",
          status: "published",
          user_id: user.id,
          category_ids: [category1.id],
          tag_ids: [tag1.id]
        })

      {:ok, _post2} =
        Content.create_post(%{
          title: "Post Two",
          content: "Content",
          status: "published",
          user_id: user.id,
          category_ids: [category2.id],
          tag_ids: []
        })

      {:ok, _post3} =
        Content.create_post(%{
          title: "Post Three",
          content: "Content",
          status: "published",
          user_id: user.id,
          category_ids: [category1.id, category2.id],
          tag_ids: []
        })

      # Query posts by category
      posts_in_category1 = Content.list_posts_by_category(category1)
      assert length(posts_in_category1) == 2

      posts_in_category2 = Content.list_posts_by_category(category2)
      assert length(posts_in_category2) == 2

      # Query posts by tag
      posts_with_tag1 = Content.list_posts_by_tag(tag1)
      assert length(posts_with_tag1) == 1
      assert hd(posts_with_tag1).id == post1.id
    end
  end
end
