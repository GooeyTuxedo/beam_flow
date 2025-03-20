# BeamFlow CMS Unit Testing Guide

This guide focuses on unit testing for the BeamFlow CMS project, providing examples and best practices for testing individual functions and modules in isolation.

## When to Use Unit Tests

Unit tests are ideal for:

* Testing pure functions
* Testing business logic
* Testing individual context functions
* Testing validations and schema constraints
* Testing helpers and utility functions

## Unit Test Examples

### Testing a Pure Function

```elixir
# lib/beam_flow/utils/slug_generator.ex
defmodule BeamFlow.Utils.SlugGenerator do
  @doc """
  Generates a URL-friendly slug from a title string.
  
  ## Examples
      iex> SlugGenerator.generate_slug("Hello World!")
      "hello-world"
  """
  def generate_slug(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/[\s-]+/, "-")
    |> String.trim("-")
  end
end

# test/beam_flow/utils/slug_generator_test.exs
defmodule BeamFlow.Utils.SlugGeneratorTest do
  use ExUnit.Case, async: true
  alias BeamFlow.Utils.SlugGenerator

  describe "generate_slug/1" do
    test "converts a title to a valid slug" do
      assert SlugGenerator.generate_slug("Hello World!") == "hello-world"
    end

    test "handles special characters" do
      assert SlugGenerator.generate_slug("This & That") == "this-that"
    end

    test "handles multiple spaces and dashes" do
      assert SlugGenerator.generate_slug("Multiple   spaces and---dashes") == "multiple-spaces-and-dashes"
    end

    test "trims dashes at the beginning and end" do
      assert SlugGenerator.generate_slug("-Trim this-") == "trim-this"
    end

    test "handles empty string" do
      assert SlugGenerator.generate_slug("") == ""
    end
  end
end
```

### Testing a Schema and Validations

```elixir
# test/beam_flow/content/post_test.exs
defmodule BeamFlow.Content.PostTest do
  use BeamFlow.DataCase, async: true
  alias BeamFlow.Content.Post

  describe "changeset/2" do
    test "valid attributes" do
      attrs = %{
        title: "Test Post",
        content: "Some content",
        status: "draft",
        user_id: Ecto.UUID.generate()
      }

      changeset = Post.changeset(%Post{}, attrs)
      assert changeset.valid?
    end

    test "requires title" do
      attrs = %{content: "Some content", status: "draft"}
      changeset = Post.changeset(%Post{}, attrs)
      assert %{title: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires content" do
      attrs = %{title: "Test Post", status: "draft"}
      changeset = Post.changeset(%Post{}, attrs)
      assert %{content: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates status" do
      attrs = %{
        title: "Test Post",
        content: "Some content",
        status: "invalid_status"
      }

      changeset = Post.changeset(%Post{}, attrs)
      assert %{status: ["is not a valid status"]} = errors_on(changeset)
    end

    test "generates slug from title" do
      attrs = %{
        title: "Test Post Title",
        content: "Some content",
        status: "draft"
      }

      changeset = Post.changeset(%Post{}, attrs)
      assert changeset.changes.slug == "test-post-title"
    end
  end
end
```

### Testing a Context Function

```elixir
# test/beam_flow/content_test.exs
defmodule BeamFlow.ContentTest do
  use BeamFlow.DataCase, async: true
  alias BeamFlow.Content
  alias BeamFlow.Accounts.User
  alias BeamFlow.Content.Post

  describe "create_post/2" do
    setup do
      {:ok, user} = BeamFlow.Repo.insert(%User{
        email: "test@example.com",
        password_hash: "some_hash",
        role: "author"
      })
      
      {:ok, user: user}
    end

    test "creates a post with valid data", %{user: user} do
      attrs = %{
        title: "Test Post",
        content: "Some test content",
        status: "draft"
      }

      assert {:ok, %Post{} = post} = Content.create_post(user, attrs)
      assert post.title == "Test Post"
      assert post.content == "Some test content"
      assert post.status == "draft"
      assert post.user_id == user.id
      assert post.slug == "test-post"
    end

    test "returns error with invalid data", %{user: user} do
      attrs = %{title: "", content: ""}
      assert {:error, %Ecto.Changeset{}} = Content.create_post(user, attrs)
    end

    test "generates a unique slug on collision", %{user: user} do
      # Create first post
      attrs1 = %{title: "Test Post", content: "Content 1", status: "draft"}
      {:ok, _post1} = Content.create_post(user, attrs1)

      # Create second post with same title
      attrs2 = %{title: "Test Post", content: "Content 2", status: "draft"}
      {:ok, post2} = Content.create_post(user, attrs2)

      # Should have a unique slug
      assert post2.slug =~ "test-post-"
      refute post2.slug == "test-post"
    end
  end
end
```

## Unit Testing Best Practices

### 1. Test Structure

Follow a consistent structure for unit tests:

```elixir
describe "function_name/arity" do
  setup do
    # Setup test data
    {:ok, data: data}
  end
  
  test "describes expected behavior", %{data: data} do
    # Arrange - prepare test data
    # Act - call the function being tested
    # Assert - verify the results
  end
end
```

### 2. Test Coverage Targets

For unit tests, aim for:
- **90%+ code coverage** for business logic and utility functions
- Every public function should have test cases covering:
  - Happy path (successful execution)
  - Error conditions
  - Edge cases

### 3. Focus on Isolation

Unit tests should test code in isolation:
- Mock or stub dependencies
- Don't rely on external services
- Tests should be independent of each other

### 4. Test Different Scenarios

For each function, consider testing:

- Valid inputs
- Invalid inputs
- Boundary conditions
- Special cases (empty strings, nil values, etc.)
- Error handling

### 5. Keep Tests Fast

Unit tests should run quickly:
- Avoid unnecessary database operations
- Use in-memory repositories where possible
- Skip time-consuming operations during setup

### 6. Test Naming Conventions

Use descriptive names to document behavior:

- Bad: `test "create post works"`
- Good: `test "create_post/2 with valid attributes creates a post with correct slug"`

## ExUnit Tips for BeamFlow

### Async Testing

Use `async: true` when tests don't share resources:

```elixir
use BeamFlow.DataCase, async: true
```

### DocTests

Use doctests for functions with simple inputs/outputs:

```elixir
@doc """
Converts a string to lowercase.

## Examples

    iex> StringUtils.downcase("HELLO")
    "hello"
"""
def downcase(string), do: String.downcase(string)
```

### Test Setup

Use `setup` for test data preparation:

```elixir
setup do
  user = %User{id: 1, name: "Test User", role: "author"}
  post = %Post{id: 1, title: "Test Post", user_id: user.id}
  
  {:ok, user: user, post: post}
end
```

### Tagged Tests

Use tags to categorize tests:

```elixir
@tag :unit
test "generates valid slug", do: # ...
```

Run specific tags:

```bash
mix test --only unit
```