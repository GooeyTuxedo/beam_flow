# BeamFlow CMS LiveView Testing Guide

This guide focuses on testing Phoenix LiveView components in the BeamFlow CMS project, providing examples and best practices for verifying LiveView behavior without requiring a full browser environment.

## When to Use LiveView Tests

LiveView tests are ideal for:

* Testing LiveView rendering with different data and user roles
* Testing LiveView event handling
* Testing LiveView component interactions
* Testing form submissions and validations
* Testing UI state transitions

## LiveView Test Examples

### Testing LiveView Rendering

```elixir
# test/beam_flow_web/live/post_live_test.exs
defmodule BeamFlowWeb.PostLiveTest do
  use BeamFlowWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias BeamFlow.Accounts
  alias BeamFlow.Content

  describe "PostLive.Index" do
    setup [:create_user_and_posts]

    test "lists all posts for admin", %{conn: conn, admin: admin, posts: posts} do
      {:ok, view, _html} = 
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/posts")

      # All posts should be visible to admin
      for post <- posts do
        assert has_element?(view, "#post-#{post.id}", post.title)
      end
    end

    test "lists only own posts for author", %{conn: conn, author: author, author_posts: author_posts, other_posts: other_posts} do
      {:ok, view, _html} = 
        conn
        |> log_in_user(author)
        |> live(~p"/author/posts")

      # Only author's posts should be visible
      for post <- author_posts do
        assert has_element?(view, "#post-#{post.id}", post.title)
      end

      # Other posts should not be visible
      for post <- other_posts do
        refute has_element?(view, "#post-#{post.id}", post.title)
      end
    end

    test "filters posts by status", %{conn: conn, admin: admin, draft_posts: draft_posts} do
      {:ok, view, _html} = 
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/posts")

      # Filter by draft status
      view
      |> element("select#status-filter")
      |> render_change(%{value: "draft"})

      # Only draft posts should be visible
      for post <- draft_posts do
        assert has_element?(view, "#post-#{post.id}", post.title)
      end
      
      # Count of visible posts should match draft count
      assert has_element?(view, ".post-count", "#{length(draft_posts)} posts")
    end

    test "searches posts by title", %{conn: conn, admin: admin, posts: posts} do
      target_post = List.first(posts)
      
      {:ok, view, _html} = 
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/posts")

      # Search for specific title
      view
      |> form("#search-form")
      |> render_submit(%{query: target_post.title})

      # Only the target post should be visible
      assert has_element?(view, "#post-#{target_post.id}", target_post.title)
      assert has_element?(view, ".post-count", "1 post")
    end
  end

  describe "PostLive.Show" do
    setup [:create_user_and_posts]

    test "displays post for admin", %{conn: conn, admin: admin, published_post: post} do
      {:ok, _view, html} = 
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/posts/#{post}")

      assert html =~ post.title
      assert html =~ post.content
    end

    test "redirects if post not authorized for author", %{conn: conn, author: author, other_posts: [other_post | _]} do
      result = 
        conn
        |> log_in_user(author)
        |> live(~p"/author/posts/#{other_post}")
        |> follow_redirect(conn)

      assert {:error, {:redirect, %{to: "/author/posts"}}} = result
      # OR with newer Phoenix versions:
      # assert {:error, {:live_redirect, %{to: "/author/posts"}}} = result
    end
  end

  defp create_user_and_posts(_) do
    # Setup users
    {:ok, admin} = Accounts.create_user(%{email: "admin@example.com", password: "password123", role: "admin"})
    {:ok, author} = Accounts.create_user(%{email: "author@example.com", password: "password123", role: "author"})
    {:ok, other_author} = Accounts.create_user(%{email: "other@example.com", password: "password123", role: "author"})
    
    # Create author posts
    {:ok, draft_post1} = Content.create_post(author, %{title: "Draft Post 1", content: "Content", status: "draft"})
    {:ok, published_post} = Content.create_post(author, %{title: "Published Post", content: "Content", status: "published"})
    author_posts = [draft_post1, published_post]
    
    # Create other author posts
    {:ok, draft_post2} = Content.create_post(other_author, %{title: "Other Draft Post", content: "Content", status: "draft"})
    other_posts = [draft_post2]
    
    # Group posts
    draft_posts = [draft_post1, draft_post2]
    posts = author_posts ++ other_posts
    
    {:ok, 
      admin: admin, 
      author: author, 
      other_author: other_author,
      published_post: published_post,
      author_posts: author_posts,
      other_posts: other_posts,
      draft_posts: draft_posts,
      posts: posts
    }
  end

  defp log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_id, user.id)
  end
end
```

### Testing LiveView Form Submission

```elixir
# test/beam_flow_web/live/post_live/form_test.exs
defmodule BeamFlowWeb.PostLive.FormTest do
  use BeamFlowWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias BeamFlow.Accounts
  alias BeamFlow.Content

  describe "PostLive.Form" do
    setup [:create_user]

    test "creates a new post with valid data", %{conn: conn, author: author} do
      {:ok, view, _html} = 
        conn
        |> log_in_user(author)
        |> live(~p"/author/posts/new")

      # Fill in and submit the form
      result =
        view
        |> form("#post-form", post: %{title: "New Post Title", content: "Some content", status: "draft"})
        |> render_submit()

      # Should redirect to the post show page
      assert_redirect(result, ~p"/author/posts/new-post-title")
      
      # Verify post was created in the database
      assert [post] = Content.list_posts_by_user(author)
      assert post.title == "New Post Title"
      assert post.content == "Some content"
      assert post.status == "draft"
    end

    test "shows errors with invalid data", %{conn: conn, author: author} do
      {:ok, view, _html} = 
        conn
        |> log_in_user(author)
        |> live(~p"/author/posts/new")

      # Submit invalid form
      updated_view =
        view
        |> form("#post-form", post: %{title: "", content: "", status: "draft"})
        |> render_submit()

      # Should show validation errors
      assert updated_view =~ "can&#39;t be blank"
      
      # Verify no post was created
      assert [] = Content.list_posts_by_user(author)
    end

    test "updates a post with valid data", %{conn: conn, author: author} do
      # Create a post first
      {:ok, post} = Content.create_post(author, %{title: "Original Title", content: "Original content", status: "draft"})
      
      {:ok, view, _html} = 
        conn
        |> log_in_user(author)
        |> live(~p"/author/posts/#{post}/edit")

      # Update the post
      result =
        view
        |> form("#post-form", post: %{title: "Updated Title", content: "Updated content"})
        |> render_submit()

      # Should redirect to the post show page
      assert_redirect(result, ~p"/author/posts/updated-title")
      
      # Verify post was updated
      updated_post = Content.get_post!(post.id)
      assert updated_post.title == "Updated Title"
      assert updated_post.content == "Updated content"
    end
  end

  defp create_user(_) do
    {:ok, author} = Accounts.create_user(%{email: "author@example.com", password: "password123", role: "author"})
    {:ok, author: author}
  end

  defp log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_id, user.id)
  end
end
```

### Testing LiveView User Interactions

```elixir
# test/beam_flow_web/live/post_live/interactions_test.exs
defmodule BeamFlowWeb.PostLive.InteractionsTest do
  use BeamFlowWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias BeamFlow.Accounts
  alias BeamFlow.Content

  describe "Post publishing" do
    setup [:create_editor_and_post]

    test "can publish a draft post", %{conn: conn, editor: editor, post: post} do
      {:ok, view, _html} = 
        conn
        |> log_in_user(editor)
        |> live(~p"/editor/posts/#{post}")

      # Verify post is in draft status
      assert has_element?(view, ".status-badge", "Draft")
      
      # Click publish button
      view
      |> element("button", "Publish")
      |> render_click()
      
      # Verify status changed to published
      assert has_element?(view, ".status-badge", "Published")
      
      # Verify flash message
      assert has_element?(view, ".alert-info", "Post published successfully")
      
      # Verify database was updated
      updated_post = Content.get_post!(post.id)
      assert updated_post.status == "published"
      assert updated_post.published_at != nil
    end

    test "publishing can be confirmed with modal", %{conn: conn, editor: editor, post: post} do
      {:ok, view, _html} = 
        conn
        |> log_in_user(editor)
        |> live(~p"/editor/posts/#{post}")
      
      # Open confirmation modal
      view
      |> element("button#publish-with-confirm")
      |> render_click()
      
      # Modal should be visible
      assert has_element?(view, ".modal", "Are you sure you want to publish?")
      
      # Confirm publication
      view
      |> element(".modal button", "Confirm")
      |> render_click()
      
      # Verify status changed
      assert has_element?(view, ".status-badge", "Published")
    end
  end

  describe "Real-time updates" do
    setup [:create_admin_and_post]

    test "shows notification when post is updated by another user", %{conn: conn, admin: admin, post: post, author: author} do
      # Admin views the post
      {:ok, admin_view, _html} = 
        conn
        |> log_in_user(admin)
        |> live(~p"/admin/posts/#{post}")
      
      # Author updates the post in a separate "session"
      Content.update_post(post, %{title: "Updated by Author"})
      
      # Simulate the broadcast (we'd normally do this via PubSub)
      send(admin_view.pid, {:post_updated, %{id: post.id, title: "Updated by Author"}})
      
      # Verify admin sees the notification
      assert has_element?(admin_view, ".update-notification", "This post was updated")
      
      # Click refresh button
      admin_view
      |> element("button", "Refresh")
      |> render_click()
      
      # Verify content is updated
      assert has_element?(admin_view, "h1", "Updated by Author")
    end
  end

  defp create_editor_and_post(_) do
    # Create users
    {:ok, editor} = Accounts.create_user(%{email: "editor@example.com", password: "password123", role: "editor"})
    {:ok, author} = Accounts.create_user(%{email: "author@example.com", password: "password123", role: "author"})
    
    # Create a draft post
    {:ok, post} = Content.create_post(author, %{
      title: "Draft Post",
      content: "This is a draft post content.",
      status: "draft"
    })
    
    {:ok, editor: editor, author: author, post: post}
  end

  defp create_admin_and_post(_) do
    # Create users
    {:ok, admin} = Accounts.create_user(%{email: "admin@example.com", password: "password123", role: "admin"})
    {:ok, author} = Accounts.create_user(%{email: "author@example.com", password: "password123", role: "author"})
    
    # Create a post
    {:ok, post} = Content.create_post(author, %{
      title: "Test Post",
      content: "This is the post content.",
      status: "draft"
    })
    
    {:ok, admin: admin, author: author, post: post}
  end

  defp log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_id, user.id)
  end
end
```

### Testing LiveView Components

```elixir
# test/beam_flow_web/live/components/post_card_component_test.exs
defmodule BeamFlowWeb.PostCardComponentTest do
  use BeamFlowWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias BeamFlowWeb.PostCardComponent
  alias BeamFlow.Content.Post

  describe "post card component" do
    test "renders post information" do
      post = %Post{
        id: "123",
        title: "Test Post",
        slug: "test-post",
        status: "published",
        published_at: ~U[2025-01-15 10:00:00Z],
        user: %{name: "Test Author"},
        excerpt: "This is a test excerpt."
      }
      
      html = render_component(PostCardComponent, id: post.id, post: post, current_user_role: "admin")
      
      # Verify basic content rendering
      assert html =~ post.title
      assert html =~ post.excerpt
      assert html =~ "Test Author"
      assert html =~ "Published"
      
      # Verify correct link is present
      assert html =~ ~s(href="/posts/test-post")
    end
    
    test "shows edit button for admin" do
      post = %Post{id: "123", title: "Test Post", slug: "test-post", status: "published"}
      
      html = render_component(PostCardComponent, id: post.id, post: post, current_user_role: "admin")
      assert html =~ "Edit"
      
      # For admin, should show edit button
      assert html =~ ~s(href="/admin/posts/123/edit")
    end
    
    test "shows edit button for author of the post" do
      user = %{id: "user1", name: "Author"}
      post = %Post{
        id: "123", 
        title: "Test Post", 
        slug: "test-post", 
        status: "published",
        user_id: "user1",
        user: user
      }
      
      html = render_component(PostCardComponent, id: post.id, post: post, current_user_role: "author", current_user_id: "user1")
      
      # Author should see edit for their own post
      assert html =~ "Edit"
      assert html =~ ~s(href="/author/posts/123/edit")
    end
    
    test "does not show edit button for other authors" do
      user = %{id: "user1", name: "Author"}
      post = %Post{
        id: "123", 
        title: "Test Post", 
        slug: "test-post", 
        status: "published",
        user_id: "user1",
        user: user
      }
      
      html = render_component(PostCardComponent, id: post.id, post: post, current_user_role: "author", current_user_id: "user2")
      
      # Different author should not see edit button
      refute html =~ "Edit"
    end
    
    test "renders draft status correctly" do
      post = %Post{
        id: "123",
        title: "Draft Post",
        slug: "draft-post",
        status: "draft"
      }
      
      html = render_component(PostCardComponent, id: post.id, post: post, current_user_role: "admin")
      
      # Should show draft badge
      assert html =~ ~s(class="status-badge draft")
      assert html =~ "Draft"
    end
  end
end
```

## LiveView Testing Best Practices

### 1. Test LiveView Mounting

Test that LiveView mounts correctly with different parameters and user roles:

```elixir
test "mounts with correct initial state", %{conn: conn, user: user} do
  {:ok, view, html} = 
    conn
    |> log_in_user(user)
    |> live(~p"/posts")
  
  # Verify initial HTML rendering
  assert html =~ "Posts"
  
  # Verify initial assigns
  assert view.module == BeamFlowWeb.PostLive.Index
  assert view.assigns.page_title == "Posts"
end
```

### 2. Test LiveView Events

Test that LiveView handles events correctly:

```elixir
test "handles filter event", %{conn: conn, user: user} do
  {:ok, view, _html} = 
    conn
    |> log_in_user(user)
    |> live(~p"/posts")
  
  # Trigger a LiveView event
  new_html = 
    view
    |> element("select#status-filter")
    |> render_change(%{value: "published"})
  
  # Verify the HTML was updated
  assert new_html =~ "Showing published posts"
end
```

### 3. Test Form Submissions

Test form submissions with both valid and invalid data:

```elixir
test "submits form with valid data", %{conn: conn, user: user} do
  {:ok, view, _html} = 
    conn
    |> log_in_user(user)
    |> live(~p"/posts/new")
  
  # Submit the form with valid data
  view
  |> form("#post-form", post: valid_post_params())
  |> render_submit()
  
  # Verify redirect
  assert_redirect(view, "/posts/new-post-title")
end

test "shows errors with invalid data", %{conn: conn, user: user} do
  {:ok, view, _html} = 
    conn
    |> log_in_user(user)
    |> live(~p"/posts/new")
  
  # Submit with invalid data
  html = 
    view
    |> form("#post-form", post: %{title: "", content: ""})
    |> render_submit()
  
  # Verify error messages are shown
  assert html =~ "can't be blank"
end
```

### 4. Test LiveView Navigation

Test navigation between LiveView routes:

```elixir
test "navigates between LiveViews", %{conn: conn, user: user} do
  {:ok, view, _html} = 
    conn
    |> log_in_user(user)
    |> live(~p"/posts")
  
  # Navigate to the new post page
  {:ok, new_view, new_html} = 
    view
    |> element("a", "New Post")
    |> render_click()
    |> follow_redirect(conn)
  
  # Verify we're on the new post page
  assert new_html =~ "New Post"
  assert new_view.module == BeamFlowWeb.PostLive.New
end
```

### 5. Test LiveView Components

Test LiveView components in isolation:

```elixir
test "renders component correctly", %{conn: _conn} do
  # Create test data
  post = %Post{id: 1, title: "Test", content: "Content"}
  
  # Render just the component
  html = render_component(MyComponent, id: "my-component", post: post)
  
  # Verify the component renders correctly
  assert html =~ "Test"
  assert html =~ "Content"
end
```

### 6. Test Real-Time Features

Test real-time features by sending messages to LiveView processes:

```elixir
test "updates in real-time", %{conn: conn, user: user, post: post} do
  {:ok, view, _html} = 
    conn
    |> log_in_user(user)
    |> live(~p"/posts/#{post.id}")
  
  # Simulate a PubSub broadcast
  send(view.pid, {:post_updated, %{title: "Updated Title"}})
  
  # Verify UI updates
  assert render(view) =~ "Updated Title"
  assert has_element?(view, ".notification", "Post was updated")
end
```

### 7. Test Different User Roles

Test LiveViews with different user roles:

```elixir
test "admin sees all controls", %{conn: conn, admin: admin} do
  {:ok, view, _html} = 
    conn
    |> log_in_user(admin)
    |> live(~p"/posts/#{post.id}")
  
  # Admin should see all controls
  assert has_element?(view, "button", "Delete")
  assert has_element?(view, "button", "Publish")
end

test "author sees limited controls", %{conn: conn, author: author} do
  {:ok, view, _html} = 
    conn
    |> log_in_user(author)
    |> live(~p"/posts/#{post.id}")
  
  # Author should see limited controls
  assert has_element?(view, "button", "Edit")
  refute has_element?(view, "button", "Publish")
end
```

## LiveView Testing Tips

### Testing Helpers

Create helper functions for common LiveView testing tasks:

```elixir
# test/support/conn_case.ex
defmodule BeamFlowWeb.ConnCase do
  # Existing imports and setup...

  # Auth helper
  def log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_id, user.id)
  end
  
  # LiveView navigation helper
  def navigate_to(view, path) do
    {:ok, view, _html} = live_redirect(view, to: path)
    view
  end
  
  # Form submission helper
  def submit_form(view, form_id, params) do
    view
    |> form(form_id, params)
    |> render_submit()
  end
  
  # LiveView click helper
  def click_element(view, selector) do
    view
    |> element(selector)
    |> render_click()
  end
end
```

### Debugging LiveView Tests

Tips for debugging LiveView tests:

1. Use `IO.inspect/1` to view LiveView assigns:
   ```elixir
   IO.inspect(view.assigns, label: "LiveView assigns")
   ```

2. Use `render/1` to see current HTML:
   ```elixir
   html = render(view)
   IO.puts(html)
   ```

3. Check for elements:
   ```elixir
   if has_element?(view, "#my-element") do
     IO.puts("Element exists")
   else
     IO.puts("Element doesn't exist")
   end
   ```

4. Examine LiveView events:
   ```elixir
   # Add debug statements in your LiveView handle_event
   def handle_event(event, params, socket) do
     IO.inspect({event, params}, label: "LiveView event")
     # Regular handler code
   end
   ```

### LiveView Test Coverage Target

For LiveView tests, aim for:

- All LiveView modules have tests
- All events are tested
- All form submissions are tested
- Different user roles are tested
- UI state transitions are verified

## Tagged Tests

Use tags to organize your LiveView tests:

```elixir
@tag :liveview
test "renders correctly", do: # ...
```

Run only LiveView tests:

```bash
mix test --only liveview
```