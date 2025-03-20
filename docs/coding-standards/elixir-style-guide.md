# Elixir Style Guide for BeamFlow CMS

This document outlines the Elixir coding standards for the BeamFlow CMS project. Following these guidelines ensures code consistency, readability, and maintainability.

## General Guidelines

### Formatting

- Use [Elixir formatter](https://hexdocs.pm/mix/main/Mix.Tasks.Format.html) with our project's `.formatter.exs` configuration.
- Run `mix format` before committing changes.
- Configure your editor to format on save if possible.

### Naming Conventions

- Use `snake_case` for variables, functions, modules, and files.
- Module names should be `PascalCase`.
- Acronyms in module names should be capitalized: `HTTPClient`, not `HttpClient`.
- Boolean functions should end with a question mark: `valid?/1`, `empty?/1`.
- Use predicate functions (`is_` prefix) only when implementing Elixir protocols.

### Function Guidelines

- Keep functions small and focused on a single responsibility.
- Limit function length to around 15-20 lines where possible.
- For function with multiple clauses, group them together and separate from other functions with a single blank line.
- Use guard clauses to make function pattern matching more explicit.

```elixir
# Good: Clean pattern matching with guards
def process_status(status) when status in ["draft", "published", "scheduled"], do: {:ok, status}
def process_status(_), do: {:error, :invalid_status}

# Avoid: Complex conditions in function body
def process_status(status) do
  if status in ["draft", "published", "scheduled"] do
    {:ok, status}
  else
    {:error, :invalid_status}
  end
end
```

### Documentation

- Document all public functions using `@doc` and `@moduledoc`.
- Include examples in documentation when helpful.
- Use `@typedoc` to document custom types.
- Follow the [Elixir documentation guidelines](https://hexdocs.pm/elixir/writing-documentation.html).

```elixir
@moduledoc """
Handles post content management operations.
"""

@doc """
Creates a new post.

## Examples

    iex> create_post(user, %{title: "My Post", content: "Content"})
    {:ok, %Post{}}

    iex> create_post(user, %{title: "", content: ""})
    {:error, %Ecto.Changeset{}}
"""
@spec create_post(User.t(), map()) :: {:ok, Post.t()} | {:error, Ecto.Changeset.t()}
def create_post(user, attrs) do
  # Function implementation
end
```

### Module Structure

- Follow a consistent module structure:
  1. `@moduledoc`
  2. Module attributes (`@attribute`)
  3. `use`, `import`, and `alias` declarations
  4. Type definitions (`@type`)
  5. Function callbacks (`@impl`, `@behaviour`)
  6. Public functions
  7. Private functions

```elixir
defmodule BeamFlow.Content.Post do
  @moduledoc """
  Schema and changeset for blog posts.
  """
  
  # Module attributes
  @statuses ["draft", "published", "scheduled"]
  
  # Use, import, alias
  use Ecto.Schema
  import Ecto.Changeset
  alias BeamFlow.Accounts.User
  
  # Schema definition
  schema "posts" do
    field :title, :string
    field :content, :string
    field :status, :string, default: "draft"
    
    belongs_to :user, User
    
    timestamps()
  end
  
  # Public functions
  def changeset(post, attrs) do
    post
    |> cast(attrs, [:title, :content, :status])
    |> validate_required([:title, :content])
    |> validate_inclusion(:status, @statuses)
  end
  
  # Private functions
  defp generate_slug(title) do
    # Implementation
  end
end
```

## Code Organization

### Context Boundaries

- Organize related functionality into contexts following Phoenix contexts pattern.
- Respect context boundaries - don't call internal functions from another context.
- Cross-context communication should happen through the context's public API.

```elixir
# Good: Using the public API
def publish_post(user, post_id) do
  with {:ok, post} <- Content.get_post(post_id),
       :ok <- Accounts.check_permission(user, :publish_post),
       {:ok, published} <- Content.update_post_status(post, "published") do
    Engagement.create_activity(user, published, :publish)
    {:ok, published}
  end
end

# Avoid: Bypassing context APIs
def publish_post(user, post_id) do
  post = Repo.get(Content.Post, post_id)
  if user.role in ["admin", "editor"] do
    post = Repo.update!(%{post | status: "published"})
    Repo.insert!(%Engagement.Activity{
      user_id: user.id,
      post_id: post.id,
      action: "publish"
    })
    {:ok, post}
  else
    {:error, :unauthorized}
  end
end
```

### Directory Structure

- Follow Phoenix 1.7+ directory structure.
- Keep related files together in appropriate directories.
- Place context modules in `lib/beam_flow/` directory.
- Place web-related modules in `lib/beam_flow_web/` directory.

## Error Handling

### Return Values

- Use the `{:ok, result}` and `{:error, reason}` pattern for functions that can fail.
- Prefer specific error tuples: `{:error, :not_found}` over generic messages.
- Use `with` for multiple operations that can fail.

```elixir
# Good: Clear success/error pattern
def publish_post(user, post_id) do
  with {:ok, post} <- get_post(post_id),
       :ok <- authorize(user, post, :publish),
       {:ok, updated} <- update_post(post, %{status: "published"}) do
    {:ok, updated}
  else
    {:error, :not_found} -> {:error, :post_not_found}
    {:error, :unauthorized} -> {:error, :not_authorized}
    {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
  end
end

# Avoid: Mixed return types
def publish_post(user, post_id) do
  post = get_post(post_id)
  if post == nil do
    nil
  else
    if authorize(user, post, :publish) do
      update_post(post, %{status: "published"})
    else
      false
    end
  end
end
```

### Exception Handling

- Use exceptions for truly exceptional conditions, not for normal control flow.
- Prefer using `with` and return values over try/catch.
- When rescuing exceptions, capture specific exception types rather than catching all exceptions.

## Testing

Refer to our [Testing Overview](../testing/overview.md) document for comprehensive guidance on testing practices, including:

- [Unit Tests](../testing/unit-tests.md)
- [Integration Tests](../testing/integration-tests.md)
- [LiveView Tests](../testing/liveflow-tests.md)
- [End-to-End Tests](../testing/end-to-end-tests.md)

## Additional Guidelines

### Performance Considerations

- Be mindful of N+1 queries; use `Repo.preload/2` and join queries appropriately.
- Use `Ecto.Multi` for transaction operations.
- Consider using Stream for processing large collections.

### Dependencies

- Be conservative when adding new dependencies.
- Evaluate library maturity, maintenance status, and community support.
- Document why a dependency was added and what it's used for.

## Resources

- [Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide)
- [Phoenix Documentation](https://hexdocs.pm/phoenix/overview.html)
- [Ecto Documentation](https://hexdocs.pm/ecto/Ecto.html)