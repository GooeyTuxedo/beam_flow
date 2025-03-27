defmodule BeamFlow.ContentTest do
  use BeamFlow.DataCase, async: true

  import BeamFlowWeb.ConnCase
  import Mock

  alias BeamFlow.Accounts
  alias BeamFlow.Content
  alias BeamFlow.Content.Media
  alias BeamFlow.Content.Post

  @valid_attrs %{
    title: "Test Post",
    content: "This is a test post content.",
    excerpt: "Test excerpt",
    status: "draft"
  }

  @valid_media_attrs %{
    filename: "test.jpg",
    original_filename: "original_test.jpg",
    content_type: "image/jpeg",
    path: "/uploads/2025/03/26/abc123.jpg",
    size: 1024,
    alt_text: "Test image"
  }

  @user_attrs %{
    email: "test@example.com",
    password: "Password123!",
    name: "Test User"
  }

  def user_fixture(attrs \\ %{}) do
    # Generate a unique email if not provided
    attrs =
      if Map.has_key?(attrs, :email) do
        attrs
      else
        Map.put(attrs, :email, "user-#{System.unique_integer()}@example.com")
      end

    {:ok, user} =
      attrs
      |> Enum.into(@user_attrs)
      |> Accounts.register_user()

    user
  end

  def post_fixture(attrs \\ %{}) do
    # Create a user if not specified
    user_id = attrs[:user_id] || user_fixture().id

    {:ok, post} =
      attrs
      |> Enum.into(@valid_attrs)
      |> Map.put(:user_id, user_id)
      |> Content.create_post()

    post
  end

  def media_fixture(attrs \\ %{}) do
    # Create a user if not specified
    user = if attrs[:user_id], do: %{id: attrs[:user_id]}, else: user_fixture()

    # Use the create_test_media helper
    create_test_media(user, attrs)
  end

  # POST TESTS

  describe "list_posts/0" do
    @tag :unit
    test "returns all posts" do
      post = post_fixture()
      posts = Content.list_posts()
      assert Enum.map(posts, & &1.id) == [post.id]
    end
  end

  describe "list_posts/1" do
    @tag :unit
    test "filters by status" do
      draft_post = post_fixture()
      published_post = post_fixture(%{status: "published"})

      draft_posts = Content.list_posts(status: "draft")
      published_posts = Content.list_posts(status: "published")

      assert Enum.map(draft_posts, & &1.id) == [draft_post.id]
      assert Enum.map(published_posts, & &1.id) == [published_post.id]
    end

    @tag :unit
    test "filters by user_id" do
      user1 = user_fixture()
      user2 = user_fixture(%{email: "another@example.com"})

      post1 = post_fixture(%{user_id: user1.id})
      post2 = post_fixture(%{user_id: user2.id})

      user1_posts = Content.list_posts(user_id: user1.id)
      user2_posts = Content.list_posts(user_id: user2.id)

      assert Enum.map(user1_posts, & &1.id) == [post1.id]
      assert Enum.map(user2_posts, & &1.id) == [post2.id]
    end

    @tag :unit
    test "filters by search term" do
      post1 = post_fixture(%{title: "Unique title"})
      post2 = post_fixture(%{content: "Content with unique phrase"})

      search_results = Content.list_posts(search: "unique")
      assert length(search_results) == 2

      results = Enum.map(search_results, & &1.id)
      assert results |> Enum.sort() == [post1.id, post2.id] |> Enum.sort()
    end

    @tag :unit
    test "orders by field" do
      _post1 = post_fixture(%{title: "Z Post"})
      _post2 = post_fixture(%{title: "A Post"})

      asc_posts = Content.list_posts(order_by: {:title, :asc})
      desc_posts = Content.list_posts(order_by: {:title, :desc})

      assert Enum.map(asc_posts, & &1.title) == ["A Post", "Z Post"]
      assert Enum.map(desc_posts, & &1.title) == ["Z Post", "A Post"]
    end

    @tag :unit
    test "limits results" do
      post_fixture()
      post_fixture()
      post_fixture()

      limited_posts = Content.list_posts(limit: 2)
      assert length(limited_posts) == 2
    end
  end

  describe "get_post!/1" do
    @tag :unit
    test "returns the post with given id" do
      post = post_fixture()
      assert Content.get_post!(post.id).id == post.id
    end

    @tag :unit
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Content.get_post!(-1)
      end
    end
  end

  describe "get_post_by_slug/1" do
    @tag :unit
    test "returns the post with given slug" do
      post = post_fixture(%{slug: "test-slug"})
      assert Content.get_post_by_slug("test-slug").id == post.id
    end

    @tag :unit
    test "returns nil if slug is not found" do
      assert Content.get_post_by_slug("nonexistent-slug") == nil
    end
  end

  describe "create_post/1" do
    @tag :unit
    test "with valid data creates a post" do
      user = user_fixture()
      attrs = Map.put(@valid_attrs, :user_id, user.id)

      assert {:ok, %Post{} = post} = Content.create_post(attrs)
      assert post.title == "Test Post"
      assert post.content == "This is a test post content."
      assert post.excerpt == "Test excerpt"
      assert post.status == "draft"
      assert post.user_id == user.id
    end

    @tag :unit
    test "with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Content.create_post(%{})
    end

    @tag :unit
    test "generates a unique slug" do
      user = user_fixture()
      attrs = Map.put(@valid_attrs, :user_id, user.id)

      assert {:ok, %Post{} = post1} = Content.create_post(attrs)
      assert post1.slug == "test-post"

      assert {:ok, %Post{} = post2} = Content.create_post(attrs)
      assert post2.slug == "test-post-2"

      assert {:ok, %Post{} = post3} = Content.create_post(attrs)
      assert post3.slug =~ ~r/test-post-\d+/
    end
  end

  describe "update_post/2" do
    @tag :unit
    test "with valid data updates the post" do
      post = post_fixture()
      update_attrs = %{title: "Updated Title", content: "Updated content"}

      assert {:ok, %Post{} = updated_post} = Content.update_post(post, update_attrs)
      assert updated_post.title == "Updated Title"
      assert updated_post.content == "Updated content"
    end

    @tag :unit
    test "with invalid data returns error changeset" do
      post = post_fixture()
      assert {:error, %Ecto.Changeset{}} = Content.update_post(post, %{title: nil})
      assert post.id == Content.get_post!(post.id).id
    end

    @tag :unit
    test "maintains slug uniqueness on update" do
      _post1 = post_fixture(%{title: "First Post"})
      post2 = post_fixture(%{title: "Second Post"})

      assert {:ok, %Post{} = updated_post} = Content.update_post(post2, %{slug: "first-post"})
      assert updated_post.slug == "first-post-2"
    end
  end

  describe "delete_post/1" do
    @tag :unit
    test "deletes the post" do
      post = post_fixture()
      assert {:ok, %Post{}} = Content.delete_post(post)
      assert_raise Ecto.NoResultsError, fn -> Content.get_post!(post.id) end
    end
  end

  describe "publish_post/1" do
    @tag :unit
    test "changes post status to published and sets published_at" do
      post = post_fixture()
      assert post.status == "draft"
      assert post.published_at == nil

      assert {:ok, published_post} = Content.publish_post(post)
      assert published_post.status == "published"
      assert published_post.published_at != nil
    end
  end

  # MEDIA TESTS

  describe "list_media/1" do
    @tag :unit
    test "returns all media" do
      user = user_fixture()
      media = create_test_media(user)
      result = Content.list_media()
      assert Enum.map(result, & &1.id) == [media.id]
    end

    @tag :unit
    test "filters by user_id" do
      user1 = user_fixture()
      user2 = user_fixture()

      media1 = create_test_media(user1)
      media2 = create_test_media(user2)

      user1_media = Content.list_media([{:user_id, user1.id}])
      user2_media = Content.list_media([{:user_id, user2.id}])

      assert Enum.map(user1_media, & &1.id) == [media1.id]
      assert Enum.map(user2_media, & &1.id) == [media2.id]
    end

    @tag :unit
    test "filters by content_type" do
      user = user_fixture()
      media1 = create_test_media(user, %{content_type: "image/jpeg"})
      media2 = create_test_media(user, %{content_type: "application/pdf"})

      jpeg_media = Content.list_media([{:content_type, "image/jpeg"}])
      pdf_media = Content.list_media([{:content_type, "application/pdf"}])

      assert Enum.map(jpeg_media, & &1.id) == [media1.id]
      assert Enum.map(pdf_media, & &1.id) == [media2.id]
    end

    @tag :unit
    test "searches by filename" do
      user = user_fixture()
      media1 = create_test_media(user, %{original_filename: "search_test.jpg"})
      _media2 = create_test_media(user, %{original_filename: "other.jpg"})

      search_results = Content.list_media([{:search, "search"}])
      assert Enum.map(search_results, & &1.id) == [media1.id]
    end
  end

  describe "get_media!/1" do
    @tag :unit
    test "returns the media with given id" do
      user = user_fixture()
      media = create_test_media(user)
      result = Content.get_media!(media.id)
      assert result.id == media.id
    end

    @tag :unit
    test "raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Content.get_media!(-1)
      end
    end
  end

  describe "create_media_from_upload/2" do
    setup do
      user = user_fixture()
      # Create a temporary file for testing
      path = Path.join(System.tmp_dir!(), "test_file.jpg")
      File.write!(path, "test content")

      on_exit(fn ->
        File.rm(path)
      end)

      %{user: user, temp_path: path}
    end

    @tag :serial
    @tag :unit
    test "creates media with valid upload", %{user: user, temp_path: path} do
      # Mock upload struct
      upload = %{
        path: path,
        content_type: "image/jpeg",
        client_name: "test_file.jpg",
        size: 1024
      }

      attrs = %{
        user_id: user.id,
        alt_text: "Test image",
        current_user: user
      }

      # Mock the store_file function to avoid filesystem operations
      with_mock BeamFlow.Content.MediaStorage,
        store_file: fn _upload, _filename -> {:ok, "/uploads/mocked_path.jpg"} end,
        delete_file: fn _path -> :ok end do
        {:ok, media} = Content.create_media_from_upload(upload, attrs)

        assert media.original_filename == "test_file.jpg"
        assert media.content_type == "image/jpeg"
        assert media.size == 1024
        assert media.user_id == user.id
        assert media.alt_text == "Test image"
      end
    end

    @tag :unit
    test "returns error for invalid content type", %{user: user, temp_path: path} do
      upload = %{
        path: path,
        content_type: "text/plain",
        client_name: "test_file.txt",
        size: 1024
      }

      attrs = %{
        user_id: user.id,
        current_user: user
      }

      assert {:error, :content_type_not_allowed} = Content.create_media_from_upload(upload, attrs)
    end
  end

  describe "update_media/2" do
    @tag :unit
    test "updates media with valid data" do
      user = user_fixture()
      media = create_test_media(user)

      attrs = %{
        alt_text: "Updated alt text",
        current_user: user
      }

      assert {:ok, updated_media} = Content.update_media(media, attrs)
      assert updated_media.alt_text == "Updated alt text"
    end
  end

  describe "delete_media/2" do
    @tag :serial
    @tag :unit
    test "deletes the media" do
      user = user_fixture()
      media = create_test_media(user)

      # Mock the delete_file function
      with_mock BeamFlow.Content.MediaStorage,
        delete_file: fn _path -> :ok end do
        assert {:ok, _media} = Content.delete_media(media, user)
        assert_raise Ecto.NoResultsError, fn -> Content.get_media!(media.id) end
      end
    end
  end

  describe "Media schema" do
    @tag :unit
    test "changeset with valid attributes" do
      user = user_fixture()
      attrs = Map.put(@valid_media_attrs, :user_id, user.id)

      changeset = Media.changeset(%Media{}, attrs)
      assert changeset.valid?
    end

    @tag :unit
    test "changeset with invalid attributes" do
      changeset = Media.changeset(%Media{}, %{})
      refute changeset.valid?
    end

    @tag :unit
    test "content_type_allowed?/1 validates content types" do
      assert Media.content_type_allowed?("image/jpeg")
      assert Media.content_type_allowed?("image/png")
      assert Media.content_type_allowed?("image/gif")
      assert Media.content_type_allowed?("image/svg+xml")
      assert Media.content_type_allowed?("application/pdf")

      refute Media.content_type_allowed?("application/exe")
      refute Media.content_type_allowed?("text/plain")
    end
  end
end
