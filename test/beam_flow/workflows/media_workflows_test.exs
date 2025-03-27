defmodule BeamFlow.Workflows.MediaWorkflowsTest do
  use BeamFlow.DataCase, async: false

  import BeamFlowWeb.ConnCase, only: [create_test_user: 1]
  import Mock

  alias BeamFlow.Content
  alias BeamFlow.Content.Media

  describe "media to post workflow" do
    setup do
      # Create users with different roles
      admin = create_test_user("admin")
      author = create_test_user("author")

      # Create a test media item
      {:ok, media} = create_test_media(author)

      {:ok, admin: admin, author: author, media: media}
    end

    @tag :integration
    test "can create post with featured image", %{author: author, media: media} do
      # Create a post with the media as featured image
      post_attrs = %{
        title: "Post with Image",
        content: "This post has a featured image",
        status: "draft",
        user_id: author.id,
        featured_image_id: media.id
      }

      {:ok, post} = Content.create_post(post_attrs)

      # Reload the post with associations
      post_with_image = Content.get_post!(post.id)

      # Verify featured image is associated
      assert post_with_image.featured_image_id == media.id
      assert post_with_image.featured_image.id == media.id
    end

    @tag :integration
    test "admin can manage any user's media", %{admin: admin, author: _author, media: media} do
      # Admin should be able to update the author's media
      update_attrs = %{
        alt_text: "Updated by admin",
        current_user: admin
      }

      {:ok, updated_media} = Content.update_media(media, update_attrs)
      assert updated_media.alt_text == "Updated by admin"

      # Admin should be able to delete the author's media
      {:ok, _media} = Content.delete_media(media, admin)
      assert_raise Ecto.NoResultsError, fn -> Content.get_media!(media.id) end
    end
  end

  describe "media authorization" do
    setup do
      # Create users with different roles
      admin = create_test_user("admin")
      author1 = create_test_user("author")
      author2 = create_test_user("author")

      # Create media for author1
      {:ok, media} = create_test_media(author1)

      {:ok, admin: admin, author1: author1, author2: author2, media: media}
    end

    @tag :integration
    test "fetches correct media based on user role", %{
      admin: _admin,
      author1: author1,
      author2: author2,
      media: _media
    } do
      # Admin should see all media
      admin_media = Content.list_media([])
      assert length(admin_media) == 1

      # Author1 should see their own media
      author1_media = Content.list_media([{:user_id, author1.id}])
      assert length(author1_media) == 1

      # Author2 should not see author1's media
      author2_media = Content.list_media([{:user_id, author2.id}])
      assert Enum.empty?(author2_media)

      # Create media for author2
      {:ok, _author2_media} = create_test_media(author2)

      # Admin should now see both media items
      admin_media = Content.list_media([])
      assert length(admin_media) == 2

      # Each author should only see their own
      author1_media = Content.list_media([{:user_id, author1.id}])
      assert length(author1_media) == 1
      author2_media = Content.list_media([{:user_id, author2.id}])
      assert length(author2_media) == 1
    end
  end

  describe "media file validations" do
    setup do
      # Create a user for testing
      author = create_test_user("author")
      {:ok, author: author}
    end

    @tag :integration
    test "rejects upload of invalid file types", %{author: author} do
      # Test directly against the Content module's create_media_from_upload function
      # Create a temp file
      path = Path.join(System.tmp_dir!(), "test_file.exe")
      File.write!(path, "fake executable content")

      upload = %{
        path: path,
        content_type: "application/exe",
        client_name: "test_file.exe",
        size: 1024
      }

      result =
        Content.create_media_from_upload(upload, %{
          user_id: author.id,
          current_user: author
        })

      # Clean up
      File.rm(path)

      # Verify rejection
      assert result == {:error, :content_type_not_allowed}
    end

    @tag :unit
    test "rejects oversized files", %{author: author} do
      max_size = Media.max_file_size()

      # Create simple validation test without mocking
      attrs = %{
        filename: "test.jpg",
        original_filename: "test.jpg",
        content_type: "image/jpeg",
        path: "/path/to/file.jpg",
        # Slightly over max
        size: max_size + 1024,
        user_id: author.id
      }

      changeset = Media.changeset(%Media{}, attrs)

      refute changeset.valid?
      assert %{size: ["must be less than or equal to " <> _rest]} = errors_on(changeset)
    end

    @tag :serial
    @tag :integration
    test "saves and retrieves media with correct metadata", %{author: author} do
      # Create a test image
      path = Path.join(System.tmp_dir!(), "test_image.jpg")
      File.write!(path, "fake image content")

      # Mock the actual store_file function to avoid filesystem operations
      with_mock BeamFlow.Content.MediaStorage,
        store_file: fn _upload, _filename -> {:ok, "/uploads/test_image.jpg"} end,
        delete_file: fn _path -> :ok end do
        # Test the full media upload flow
        upload = %{
          path: path,
          content_type: "image/jpeg",
          client_name: "original_filename.jpg",
          size: 1024
        }

        attrs = %{
          user_id: author.id,
          alt_text: "Test alt text",
          current_user: author
        }

        {:ok, media} = Content.create_media_from_upload(upload, attrs)

        # Verify metadata was saved correctly
        assert media.original_filename == "original_filename.jpg"
        assert media.content_type == "image/jpeg"
        assert media.size == 1024
        assert media.alt_text == "Test alt text"
        assert media.user_id == author.id

        # Verify we can retrieve the media
        retrieved = Content.get_media!(media.id)
        assert retrieved.id == media.id
        assert retrieved.path == "/uploads/test_image.jpg"

        # Clean up
        File.rm(path)
      end
    end
  end

  defp create_test_media(user) do
    # Create a temp file
    path = Path.join(System.tmp_dir!(), "test_file.jpg")
    File.write!(path, "test content")

    # Create test file info
    file_info = %{
      path: path,
      content_type: "image/jpeg",
      client_name: "test_file.jpg",
      size: 1024
    }

    # Create media record
    result =
      Content.create_media_from_upload(file_info, %{
        user_id: user.id,
        alt_text: "Test image",
        current_user: user
      })

    # Clean up temp file
    File.rm(path)

    result
  end
end
