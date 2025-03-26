defmodule BeamFlow.Content.PostFiltersTest do
  use BeamFlow.DataCase, async: true
  alias BeamFlow.Content

  setup do
    # Create test user
    user = BeamFlowWeb.ConnCase.create_test_user("author")

    # Create categories
    {:ok, category1} = Content.create_category(%{name: "Technology"})
    {:ok, category2} = Content.create_category(%{name: "Elixir"})
    {:ok, category3} = Content.create_category(%{name: "Phoenix"})

    # Create tags
    {:ok, tag1} = Content.create_tag(%{name: "Programming"})
    {:ok, tag2} = Content.create_tag(%{name: "Web"})
    {:ok, tag3} = Content.create_tag(%{name: "Database"})

    # Create test posts with various combinations
    {:ok, post1} =
      Content.create_post(%{
        title: "Elixir Basics",
        content: "Elixir content",
        status: "published",
        user_id: user.id,
        category_ids: [category1.id, category2.id],
        tag_ids: [tag1.id]
      })

    {:ok, post2} =
      Content.create_post(%{
        title: "Phoenix LiveView",
        content: "Phoenix content",
        status: "published",
        user_id: user.id,
        category_ids: [category3.id],
        tag_ids: [tag1.id, tag2.id]
      })

    {:ok, post3} =
      Content.create_post(%{
        title: "Ecto Basics",
        content: "Ecto content",
        status: "draft",
        user_id: user.id,
        category_ids: [category2.id, category3.id],
        tag_ids: [tag1.id, tag3.id]
      })

    {:ok,
     user: user,
     categories: [category1, category2, category3],
     tags: [tag1, tag2, tag3],
     posts: [post1, post2, post3]}
  end

  describe "list_posts/1" do
    @tag :unit
    @tag :filtering
    test "filters posts by status", %{posts: _posts} do
      published = Content.list_posts(status: "published")
      assert length(published) == 2

      drafts = Content.list_posts(status: "draft")
      assert length(drafts) == 1
      assert hd(drafts).title == "Ecto Basics"
    end

    @tag :unit
    @tag :filtering
    test "filters posts by user_id", %{user: user, posts: _posts} do
      user_posts = Content.list_posts(user_id: user.id)
      assert length(user_posts) == 3
    end

    @tag :unit
    @tag :filtering
    test "filters posts by search term", %{posts: _posts} do
      # Search for posts containing "Elixir"
      elixir_posts = Content.list_posts(search: "Elixir")
      assert length(elixir_posts) == 1
      assert hd(elixir_posts).title == "Elixir Basics"

      # Search for posts containing "content"
      content_posts = Content.list_posts(search: "content")
      assert length(content_posts) == 3
    end

    @tag :unit
    @tag :filtering
    test "orders posts", %{posts: _posts} do
      # Order by title ascending
      asc_posts = Content.list_posts(order_by: {:title, :asc})
      titles = Enum.map(asc_posts, & &1.title)
      assert titles == ["Ecto Basics", "Elixir Basics", "Phoenix LiveView"]

      # Order by title descending
      desc_posts = Content.list_posts(order_by: {:title, :desc})
      titles = Enum.map(desc_posts, & &1.title)
      assert titles == ["Phoenix LiveView", "Elixir Basics", "Ecto Basics"]
    end

    @tag :unit
    @tag :filtering
    test "limits number of posts", %{posts: _posts} do
      limited_posts = Content.list_posts(limit: 2)
      assert length(limited_posts) == 2
    end

    @tag :unit
    @tag :filtering
    test "combines multiple criteria", %{user: user, posts: _posts} do
      # Published posts by user with "Basics" in title
      filtered_posts =
        Content.list_posts(
          status: "published",
          user_id: user.id,
          search: "Basics"
        )

      assert length(filtered_posts) == 1
      assert hd(filtered_posts).title == "Elixir Basics"
    end
  end

  describe "list_posts_by_category/1" do
    @tag :unit
    @tag :filtering
    test "lists posts in a category", %{categories: [category1, category2, category3]} do
      # Posts in category1 (Technology)
      tech_posts = Content.list_posts_by_category(category1)
      assert length(tech_posts) == 1
      assert hd(tech_posts).title == "Elixir Basics"

      # Posts in category2 (Elixir)
      elixir_posts = Content.list_posts_by_category(category2)
      assert length(elixir_posts) == 2
      titles = Enum.map(elixir_posts, & &1.title)
      sorted_titles = Enum.sort(titles)
      assert sorted_titles == ["Ecto Basics", "Elixir Basics"]

      # Posts in category3 (Phoenix)
      phoenix_posts = Content.list_posts_by_category(category3)
      assert length(phoenix_posts) == 2
      titles = Enum.map(phoenix_posts, & &1.title)
      sorted_titles = Enum.sort(titles)
      assert sorted_titles == ["Ecto Basics", "Phoenix LiveView"]
    end
  end

  describe "list_posts_by_tag/1" do
    @tag :unit
    @tag :filtering
    test "lists posts with a tag", %{tags: [tag1, tag2, tag3]} do
      # Posts with tag1 (Programming)
      programming_posts = Content.list_posts_by_tag(tag1)
      assert length(programming_posts) == 3

      # Posts with tag2 (Web)
      web_posts = Content.list_posts_by_tag(tag2)
      assert length(web_posts) == 1
      assert hd(web_posts).title == "Phoenix LiveView"

      # Posts with tag3 (Database)
      db_posts = Content.list_posts_by_tag(tag3)
      assert length(db_posts) == 1
      assert hd(db_posts).title == "Ecto Basics"
    end
  end
end
