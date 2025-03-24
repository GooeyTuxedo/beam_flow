defmodule BeamFlowWeb.API.V1.PostControllerTest do
  use BeamFlowWeb.ConnCase, async: true

  # Add integration tag to the module
  @moduletag :integration

  import BeamFlow.APITestHelpers

  setup %{conn: conn} do
    admin = create_user(:admin)
    editor = create_user(:editor)
    author = create_user(:author)
    subscriber = create_user(:subscriber)

    # Create some posts for testing
    admin_post = create_post(admin, %{title: "Admin Post", status: "published"})
    editor_post = create_post(editor, %{title: "Editor Post", status: "published"})
    author_post = create_post(author, %{title: "Author Post", status: "draft"})

    %{
      conn: conn,
      admin: admin,
      editor: editor,
      author: author,
      subscriber: subscriber,
      admin_post: admin_post,
      editor_post: editor_post,
      author_post: author_post
    }
  end

  describe "index" do
    @tag :integration
    test "lists all posts", %{conn: conn} do
      response =
        conn
        |> api_request(:get, "/api/v1/posts")
        |> json_response(200)

      # At least the published posts
      assert length(response["data"]) >= 2

      # Check that response contains posts data
      post = Enum.find(response["data"], &(&1["status"] == "published"))
      assert post["title"]
      assert post["slug"]
      assert post["status"] == "published"
    end

    @tag :integration
    test "filters posts by status", %{conn: conn} do
      response =
        conn
        |> api_request(:get, "/api/v1/posts?status=draft")
        |> json_response(200)

      assert length(response["data"]) >= 1

      # Check that all returned posts are drafts
      Enum.each(response["data"], fn post ->
        assert post["status"] == "draft"
      end)
    end

    @tag :integration
    test "filters posts by search term", %{conn: conn, admin_post: admin_post} do
      response =
        conn
        |> api_request(:get, "/api/v1/posts?search=#{admin_post.title}")
        |> json_response(200)

      # Should at least find the admin post
      assert length(response["data"]) >= 1

      # First post should be the admin post
      post = Enum.find(response["data"], &(&1["title"] == admin_post.title))
      assert post
      assert post["id"] == admin_post.id
    end
  end

  describe "show" do
    @tag :integration
    test "returns a single post", %{conn: conn, admin_post: post} do
      response =
        conn
        |> api_request(:get, "/api/v1/posts/#{post.id}")
        |> json_response(200)

      assert response["data"]["id"] == post.id
      assert response["data"]["title"] == post.title
      assert response["data"]["status"] == post.status
      assert response["data"]["author"]
    end

    @tag :integration
    test "returns error when post doesn't exist", %{conn: conn} do
      response =
        conn
        |> api_request(:get, "/api/v1/posts/9999999")
        |> json_response(404)

      assert response["error"]["status"] == 404
      assert response["error"]["message"] == "Post not found"
    end
  end

  describe "create" do
    @tag :integration
    test "creates a post with valid data when admin", %{conn: conn, admin: admin} do
      post_params = %{
        post: %{
          title: "Test API Post",
          content: "This is content from API test",
          status: "draft"
        }
      }

      response =
        conn
        |> api_request(:post, "/api/v1/posts", post_params, admin)
        |> json_response(201)

      assert response["data"]["title"] == post_params.post.title
      assert response["data"]["status"] == post_params.post.status
      assert response["data"]["author"]["id"] == admin.id
    end

    @tag :integration
    test "creates a post with valid data when author", %{conn: conn, author: author} do
      post_params = %{
        post: %{
          title: "Author API Test Post",
          content: "Author content test",
          status: "draft"
        }
      }

      response =
        conn
        |> api_request(:post, "/api/v1/posts", post_params, author)
        |> json_response(201)

      assert response["data"]["title"] == post_params.post.title
      assert response["data"]["author"]["id"] == author.id
    end

    @tag :integration
    test "returns validation error with invalid data", %{conn: conn, admin: admin} do
      post_params = %{
        post: %{
          # Missing title
          content: "This should fail",
          status: "invalid-status"
        }
      }

      response =
        conn
        |> api_request(:post, "/api/v1/posts", post_params, admin)
        |> json_response(422)

      assert response["error"]["status"] == 422
      assert response["error"]["details"]["title"]
      assert response["error"]["details"]["status"]
    end

    @tag :integration
    test "returns error when subscriber tries to create post", %{
      conn: conn,
      subscriber: subscriber
    } do
      post_params = %{
        post: %{
          title: "Subscriber Post",
          content: "This should fail",
          status: "draft"
        }
      }

      response =
        conn
        |> api_request(:post, "/api/v1/posts", post_params, subscriber)
        |> json_response(403)

      assert response["error"]["status"] == 403
      assert response["error"]["message"] == "Not authorized to create posts"
    end

    @tag :integration
    test "returns error when unauthenticated", %{conn: conn} do
      post_params = %{
        post: %{
          title: "Unauthenticated Post",
          content: "This should fail",
          status: "draft"
        }
      }

      response =
        conn
        |> api_request(:post, "/api/v1/posts", post_params)
        |> json_response(401)

      assert response["error"]["status"] == 401
    end
  end

  describe "update" do
    @tag :integration
    test "updates a post when admin", %{conn: conn, admin: admin, author_post: post} do
      update_params = %{
        post: %{
          title: "Updated by Admin",
          status: "published"
        }
      }

      response =
        conn
        |> api_request(:put, "/api/v1/posts/#{post.id}", update_params, admin)
        |> json_response(200)

      assert response["data"]["id"] == post.id
      assert response["data"]["title"] == update_params.post.title
      assert response["data"]["status"] == update_params.post.status
    end

    @tag :integration
    test "updates own post when author", %{conn: conn, author: author, author_post: post} do
      update_params = %{
        post: %{
          title: "Updated by Author",
          content: "New content"
        }
      }

      response =
        conn
        |> api_request(:put, "/api/v1/posts/#{post.id}", update_params, author)
        |> json_response(200)

      assert response["data"]["id"] == post.id
      assert response["data"]["title"] == update_params.post.title
      assert response["data"]["content"] == update_params.post.content
    end

    @tag :integration
    test "cannot update another author's post", %{conn: conn, author_post: post} do
      other_author = create_user(:author)

      update_params = %{
        post: %{
          title: "This should fail"
        }
      }

      response =
        conn
        |> api_request(:put, "/api/v1/posts/#{post.id}", update_params, other_author)
        |> json_response(403)

      assert response["error"]["status"] == 403
    end

    @tag :integration
    test "returns error when post doesn't exist", %{conn: conn, admin: admin} do
      update_params = %{
        post: %{
          title: "Nonexistent Post"
        }
      }

      response =
        conn
        |> api_request(:put, "/api/v1/posts/9999999", update_params, admin)
        |> json_response(404)

      assert response["error"]["status"] == 404
    end
  end

  describe "delete" do
    @tag :integration
    test "deletes a post when admin", %{conn: conn, admin: admin} do
      post = create_post(admin)

      conn
      |> api_request(:delete, "/api/v1/posts/#{post.id}", %{}, admin)
      |> response(:no_content)

      # Verify post is deleted
      response =
        conn
        |> api_request(:get, "/api/v1/posts/#{post.id}")
        |> json_response(404)

      assert response["error"]["status"] == 404
    end

    @tag :integration
    test "deletes own post when author", %{conn: conn, author: author} do
      post = create_post(author)

      conn
      |> api_request(:delete, "/api/v1/posts/#{post.id}", %{}, author)
      |> response(:no_content)

      # Verify post is deleted
      response =
        conn
        |> api_request(:get, "/api/v1/posts/#{post.id}")
        |> json_response(404)

      assert response["error"]["status"] == 404
    end

    @tag :integration
    test "cannot delete another author's post", %{conn: conn, author_post: post} do
      other_author = create_user(:author)

      response =
        conn
        |> api_request(:delete, "/api/v1/posts/#{post.id}", %{}, other_author)
        |> json_response(403)

      assert response["error"]["status"] == 403
    end

    @tag :integration
    test "cannot delete post as subscriber", %{
      conn: conn,
      admin_post: post,
      subscriber: subscriber
    } do
      response =
        conn
        |> api_request(:delete, "/api/v1/posts/#{post.id}", %{}, subscriber)
        |> json_response(403)

      assert response["error"]["status"] == 403
    end

    @tag :integration
    test "returns error when post doesn't exist", %{conn: conn, admin: admin} do
      response =
        conn
        |> api_request(:delete, "/api/v1/posts/9999999", %{}, admin)
        |> json_response(404)

      assert response["error"]["status"] == 404
    end
  end
end
