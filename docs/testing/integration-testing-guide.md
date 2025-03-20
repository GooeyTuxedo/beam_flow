# BeamFlow CMS Integration Testing Guide

This guide focuses on integration testing for the BeamFlow CMS project, providing examples and best practices for testing interactions between different components and contexts.

## When to Use Integration Tests

Integration tests are ideal for:

* Testing workflows that span multiple contexts
* Testing database transactions and constraints
* Testing authorization and policy enforcement
* Testing cache behavior
* Testing service interactions

## Integration Test Examples

### Testing Cross-Context Workflow

```elixir
# test/beam_flow/workflows/post_publication_test.exs
defmodule BeamFlow.Workflows.PostPublicationTest do
  use BeamFlow.DataCase, async: true
  alias BeamFlow.Content
  alias BeamFlow.Engagement
  alias BeamFlow.Accounts
  alias BeamFlow.Accounts.User

  describe "post publication workflow" do
    setup do
      {:ok, admin} = Accounts.create_user(%{
        email: "admin@example.com",
        password: "password123",
        role: "admin"
      })
      
      {:ok, author} = Accounts.create_user(%{
        email: "author@example.com",
        password: "password123",
        role: "author"
      })
      
      {:ok, post} = Content.create_post(author, %{
        title: "Draft Post",
        content: "Some content",
        status: "draft"
      })
      
      {:ok, admin: admin, author: author, post: post}
    end

    test "publishing a post creates an activity record and updates analytics", %{admin: admin, post: post} do
      # Publish the post as admin
      {:ok, published_post} = Content.publish_post(admin, post.id)
      
      # Verify post is published
      assert published_post.status == "published"
      assert published_post.published_at != nil
      
      # Verify activity record was created
      activities = Engagement.list_activities_for_post(post.id)
      assert length(activities) == 1
      activity = List.first(activities)
      assert activity.action == "publish"
      assert activity.user_id == admin.id
      assert activity.post_id == post.id
      
      # Verify analytics entry was created
      analytics = Engagement.get_post_analytics(post.id)
      assert analytics.views == 0
      assert analytics.status == "published"
    end
    
    test "only editors and admins can publish posts", %{author: author, post: post} do
      # Author tries to publish their own post
      assert {:error, :unauthorized} = Content.publish_post(author, post.id)
      
      # Verify post remains draft
      updated_post = Content.get_post!(post.id)
      assert updated_post.status == "draft"
    end
  end
end
```

### Testing Authorization Policies

```elixir
# test/beam_flow/policies/post_policy_test.exs
defmodule BeamFlow.Policies.PostPolicyTest do
  use BeamFlow.DataCase, async: true
  alias BeamFlow.Policies.PostPolicy
  alias BeamFlow.Content
  alias BeamFlow.Accounts
  alias BeamFlow.Accounts.User
  alias BeamFlow.Content.Post

  setup do
    {:ok, admin} = Accounts.create_user(%{email: "admin@example.com", password: "password123", role: "admin"})
    {:ok, editor} = Accounts.create_user(%{email: "editor@example.com", password: "password123", role: "editor"})
    {:ok, author} = Accounts.create_user(%{email: "author@example.com", password: "password123", role: "author"})
    {:ok, other_author} = Accounts.create_user(%{email: "other@example.com", password: "password123", role: "author"})
    
    {:ok, author_post} = Content.create_post(author, %{title: "Author Post", content: "Content", status: "draft"})
    
    {:ok, 
      admin: admin, 
      editor: editor, 
      author: author, 
      other_author: other_author, 
      author_post: author_post
    }
  end

  describe "can_view?/2" do
    test "admin can view any post", %{admin: admin, author_post: post} do
      assert PostPolicy.can_view?(admin, post)
    end
    
    test "editor can view any post", %{editor: editor, author_post: post} do
      assert PostPolicy.can_view?(editor, post)
    end
    
    test "author can view own post", %{author: author, author_post: post} do
      assert PostPolicy.can_view?(author, post)
    end
    
    test "author cannot view other's draft post", %{other_author: other_author, author_post: post} do
      refute PostPolicy.can_view?(other_author, post)
    end
    
    test "anyone can view published post", %{other_author: other_author, author_post: post} do
      # Publish the post first
      {:ok, published_post} = Content.update_post(post, %{status: "published"})
      assert PostPolicy.can_view?(other_author, published_post)
    end
  end

  describe "can_edit?/2" do
    test "admin can edit any post", %{admin: admin, author_post: post} do
      assert PostPolicy.can_edit?(admin, post)
    end
    
    test "editor can edit any post", %{editor: editor, author_post: post} do
      assert PostPolicy.can_edit?(editor, post)
    end
    
    test "author can edit own post", %{author: author, author_post: post} do
      assert PostPolicy.can_edit?(author, post)
    end
    
    test "author cannot edit others' posts", %{other_author: other_author, author_post: post} do
      refute PostPolicy.can_edit?(other_author, post)
    end
  end

  describe "can_publish?/2" do
    test "admin can publish any post", %{admin: admin, author_post: post} do
      assert PostPolicy.can_publish?(admin, post)
    end
    
    test "editor can publish any post", %{editor: editor, author_post: post} do
      assert PostPolicy.can_publish?(editor, post)
    end
    
    test "author cannot publish own post", %{author: author, author_post: post} do
      refute PostPolicy.can_publish?(author, post)
    end
  end
end
```

### Testing Database Constraints

```elixir
# test/beam_flow/database/constraints_test.exs
defmodule BeamFlow.Database.ConstraintsTest do
  use BeamFlow.DataCase, async: true
  alias BeamFlow.Content
  alias BeamFlow.Accounts
  alias BeamFlow.Repo

  describe "database constraints" do
    setup do
      {:ok, user} = Accounts.create_user(%{
        email: "test@example.com",
        password: "password123",
        role: "author"
      })
      
      {:ok, user: user}
    end

    test "unique constraint on user email", %{user: _user} do
      # Try to create another user with the same email
      result = Accounts.create_user(%{
        email: "test@example.com", 
        password: "different123",
        role: "author"
      })
      
      assert {:error, changeset} = result
      assert %{email: ["has already been taken"]} = errors_on(changeset)
    end

    test "foreign key constraint on post's user_id", %{user: user} do
      # Create a post
      {:ok, post} = Content.create_post(user, %{
        title: "Test Post",
        content: "Some content",
        status: "draft"
      })
      
      # Delete the user
      Repo.delete(user)
      
      # Try to update the post, which should fail due to the FK constraint
      {:error, changeset} = Content.update_post(post, %{title: "Updated Title"})
      
      # The exact error message might vary based on your DB setup
      # But it should indicate a foreign key violation
      assert changeset.errors[:user_id]
    end

    test "cascade delete of posts when user is deleted", %{user: user} do
      # Create several posts for the user
      {:ok, _post1} = Content.create_post(user, %{title: "Post 1", content: "Content 1", status: "draft"})
      {:ok, _post2} = Content.create_post(user, %{title: "Post 2", content: "Content 2", status: "draft"})
      
      # Verify posts exist
      assert length(Content.list_posts_by_user(user)) == 2
      
      # Configure cascade delete in your schema (ensure this is set up)
      # In the User schema:
      # has_many :posts, Post, on_delete: :delete_all
      
      # Delete the user
      Repo.delete(user)
      
      # Verify posts were also deleted
      assert Repo.all(Content.Post) |> length() == 0
    end
  end
end
```

## Integration Testing Best Practices

### 1. Test Complete Workflows

Integration tests should test full workflows that span multiple contexts or services:

- Test from beginning to end of a business process
- Verify all side effects (e.g., records created in multiple contexts)
- Test both happy paths and error scenarios

### 2. Focus on Interactions

Focus on testing how different parts of the application interact:

- Context boundaries
- Database transactions
- Policy enforcement
- Event handling

### 3. Set Up Complete Test Environment

Create a complete test environment:

- Populate the database with all necessary data
- Set up any required services
- Configure any needed state

```elixir
setup do
  # Create a complete set of users with different roles
  {:ok, admin} = Accounts.create_user(%{role: "admin", ...})
  {:ok, editor} = Accounts.create_user(%{role: "editor", ...})
  {:ok, author} = Accounts.create_user(%{role: "author", ...})
  
  # Create initial content
  {:ok, post} = Content.create_post(author, %{...})
  
  # Return all created entities
  {:ok, 
    admin: admin, 
    editor: editor, 
    author: author, 
    post: post
  }
end
```

### 4. Test Database Constraints

Test important database constraints and triggers:

- Unique constraints
- Foreign key constraints
- Cascading deletions
- Check constraints

### 5. Test Transactions

Test transaction behavior:

- Ensure operations are atomic
- Test rollback behavior
- Test concurrent operations

```elixir
test "transaction rolls back on error" do
  # Set up initial state
  
  # Attempt an operation that should fail mid-transaction
  result = SomeContext.perform_complex_operation(args)
  
  # Verify the operation failed
  assert {:error, _reason} = result
  
  # Verify no changes were persisted
  assert database_remains_unchanged()
end
```

### 6. Clean Up After Tests

Always clean up after tests to avoid interference between tests:

- Use `setup` and `setup_all` callbacks
- Use database transactions in tests
- Explicitly clean up created resources if necessary

## Test Coverage Guidelines

For integration tests, aim for:

- Key workflows have comprehensive integration tests
- Cross-context interactions are thoroughly tested
- Authorization policies have complete coverage
- Database constraints and transactions are validated

## Tagged Tests

Use tags to categorize tests:

```elixir
@tag :integration
test "publishing workflow completes successfully", do: # ...
```

Run only integration tests:

```bash
mix test --only integration
```

## DataCase Helper Functions

Create helper functions in your DataCase module for common integration testing tasks:

```elixir
# test/support/data_case.ex
defmodule BeamFlow.DataCase do
  # Existing imports and setup...

  # Helper for transaction tests
  def in_transaction?() do
    # Check if we're in a transaction
    {:ok, %{rows: [[result]]}} = Repo.query("SELECT pg_in_transaction()")
    result
  end
  
  # Helper for checking constraint violations
  def assert_constraint_violation(changeset, constraint_name) do
    assert changeset.valid? == false
    assert changeset.errors[constraint_name]
  end
  
  # Helper for creating a full test environment
  def create_test_environment() do
    # Create standard testing data (users, posts, etc.)
    # Return a map of created entities
  end
end
```