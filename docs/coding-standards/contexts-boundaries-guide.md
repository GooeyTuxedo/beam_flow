# Context Design and Boundaries for BeamFlow CMS

This guide explains the context structure in BeamFlow CMS and provides guidelines for maintaining proper context boundaries when adding new features.

## Context Overview

BeamFlow CMS is organized into the following contexts:

1. **Accounts** - User management, authentication, and authorization
2. **Content** - Posts, categories, tags, and media management
3. **Engagement** - Comments, analytics, and user interactions
4. **Site** - Site settings, themes, and configuration

This organization allows for clear separation of concerns and helps maintain a clean domain model.

## Context Boundaries

### Why Boundaries Matter

Context boundaries help create a maintainable codebase by:

- Preventing circular dependencies
- Reducing coupling between unrelated parts of the application
- Making the codebase easier to reason about
- Improving testability

### Rules for Respecting Boundaries

1. **Public vs. Private APIs**
   - Only expose necessary functions in the context module
   - Keep implementation details private
   - Don't access internal functions of other contexts

2. **Cross-Context Communication**
   - Contexts should communicate only through their public APIs
   - Don't directly access schemas or internal functions of other contexts

3. **Data Ownership**
   - Each context owns its schemas and data
   - Other contexts should request data through the owning context's public API

## Adding New Features

When adding a new feature, follow these steps:

1. **Identify the appropriate context**
   - Which domain concept does this feature relate to?
   - Which context is responsible for this data?

2. **Design the public API**
   - What functions need to be exposed?
   - What data should be returned?
   - How should errors be handled?

3. **Implement within the context**
   - Keep implementation details private
   - Use schema modules appropriately
   - Design a clean internal structure

4. **Connect to other contexts if needed**
   - Use only the public APIs of other contexts
   - Consider using PubSub for cross-context communication

## Examples of Proper Context Usage

### Example 1: Creating a Post with Tags

```elixir
# In a LiveView or controller
def create_post(conn, %{"post" => post_params}) do
  user = conn.assigns.current_user
  
  with {:ok, post} <- Content.create_post(user, post_params),
       :ok <- Engagement.track_activity(user, post, :create) do
    conn
    |> put_flash(:info, "Post created successfully.")
    |> redirect(to: ~p"/posts/#{post}")
  else
    {:error, %Ecto.Changeset{} = changeset} ->
      render(conn, :new, changeset: changeset)
  end
end

# In the Content context (lib/beam_flow/content.ex)
def create_post(user, attrs) do
  # Authorize the action using Accounts context
  with :ok <- Accounts.authorize(user, :create_post) do
    %Post{}
    |> Post.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:user, user)
    |> Repo.insert()
  end
end

# In the Engagement context (lib/beam_flow/engagement.ex)
def track_activity(user, post, action) do
  %Activity{}
  |> Activity.changeset(%{
    user_id: user.id,
    post_id: post.id,
    action: action
  })
  |> Repo.insert()
  |> case do
    {:ok, _activity} -> :ok
    {:error, changeset} -> {:error, changeset}
  end
end
```

### Example 2: Publishing a Post with Notifications

```elixir
# In a LiveView or controller
def publish_post(conn, %{"id" => id}) do
  user = conn.assigns.current_user
  
  with {:ok, post} <- Content.get_post(id),
       :ok <- Content.authorize(user, post, :publish),
       {:ok, published_post} <- Content.publish_post(post),
       :ok <- Engagement.notify_subscribers(published_post) do
    conn
    |> put_flash(:info, "Post published successfully.")
    |> redirect(to: ~p"/posts/#{published_post}")
  else
    {:error, :not_found} ->
      conn
      |> put_flash(:error, "Post not found.")
      |> redirect(to: ~p"/posts")
      
    {:error, :unauthorized} ->
      conn
      |> put_flash(:error, "You are not authorized to publish this post.")
      |> redirect(to: ~p"/posts")
      
    {:error, %Ecto.Changeset{} = changeset} ->
      conn
      |> put_flash(:error, "Error publishing post.")
      |> redirect(to: ~p"/posts/#{id}/edit")
  end
end

# In the Content context (lib/beam_flow/content.ex)
def publish_post(post) do
  post
  |> Post.publish_changeset(%{status: "published", published_at: DateTime.utc_now()})
  |> Repo.update()
end

# In the Engagement context (lib/beam_flow/engagement.ex)
def notify_subscribers(post) do
  subscribers = list_subscribers(post.user_id)
  
  Enum.each(subscribers, fn subscriber ->
    send_notification(subscriber, post)
  end)
  
  BeamFlowWeb.Endpoint.broadcast("posts", "published", %{
    id: post.id,
    title: post.title
  })
  
  :ok
end
```

## Cross-Context Communication Patterns

### 1. Direct API Calls

The simplest form of cross-context communication is direct API calls:

```elixir
# Content context using Accounts context
def create_post(user, attrs) do
  with :ok <- Accounts.authorize(user, :create_post) do
    # Create the post
  end
end
```

### 2. PubSub for Event-Driven Communication

For loosely coupled communication, use PubSub:

```elixir
# In Content context after updating a post
def update_post(post, attrs) do
  with {:ok, updated_post} <- do_update_post(post, attrs) do
    Phoenix.PubSub.broadcast(
      BeamFlow.PubSub,
      "post:#{post.id}",
      {:post_updated, updated_post}
    )
    
    {:ok, updated_post}
  end
end

# In another context or LiveView
def mount(_params, _session, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(BeamFlow.PubSub, "post:#{post_id}")
  end
  
  {:ok, socket}
end

def handle_info({:post_updated, post}, socket) do
  # Handle the update
  {:noreply, assign(socket, :post, post)}
end
```

### 3. Using Callbacks or Behaviors

For more formal interfaces between contexts:

```elixir
# Define a behavior in Engagement
defmodule BeamFlow.Engagement.NotifierBehavior do
  @callback notify_post_published(post :: BeamFlow.Content.Post.t()) :: :ok | {:error, term()}
end

# Implement in a specific module
defmodule BeamFlow.Engagement.EmailNotifier do
  @behaviour BeamFlow.Engagement.NotifierBehavior
  
  @impl true
  def notify_post_published(post) do
    # Implementation
    :ok
  end
end

# Register implementations
config :beam_flow, :notifiers, [
  BeamFlow.Engagement.EmailNotifier,
  BeamFlow.Engagement.WebNotifier
]

# Use in Content context
def publish_post(post) do
  with {:ok, published} <- do_publish_post(post) do
    notifiers = Application.get_env(:beam_flow, :notifiers, [])
    
    Enum.each(notifiers, fn notifier ->
      notifier.notify_post_published(published)
    end)
    
    {:ok, published}
  end
end
```

## Common Anti-Patterns to Avoid

### 1. Accessing Schemas Directly

```elixir
# AVOID: Content context directly accessing Accounts schemas
def create_post_with_author(attrs) do
  # This violates context boundaries by directly accessing the User schema
  author = BeamFlow.Repo.get!(BeamFlow.Accounts.User, attrs["author_id"])
  
  %Post{}
  |> Post.changeset(attrs)
  |> Ecto.Changeset.put_assoc(:user, author)
  |> Repo.insert()
end

# BETTER: Use the public API
def create_post(attrs) do
  with {:ok, author} <- BeamFlow.Accounts.get_user(attrs["author_id"]) do
    %Post{}
    |> Post.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:user, author)
    |> Repo.insert()
  end
end
```

### 2. Circular Dependencies

```elixir
# AVOID: Creating circular dependencies between contexts
# In Accounts context
def get_user_with_posts(id) do
  user = Repo.get!(User, id)
  posts = Content.list_posts_by_user(user)
  
  %{user | posts: posts}
end

# In Content context
def list_posts_by_user(user) do
  # This now relies on Accounts, creating a circular dependency
  author_details = Accounts.get_author_details(user)
  
  Post
  |> where(user_id: ^user.id)
  |> preload(:categories)
  |> Repo.all()
  |> Enum.map(&Map.put(&1, :author_details, author_details))
end

# BETTER: Keep contexts independent
# In Accounts context
def get_user(id) do
  Repo.get(User, id)
end

# In Content context
def list_posts_by_user(user) do
  Post
  |> where(user_id: ^user.id)
  |> preload(:categories)
  |> Repo.all()
end
```

### 3. Bypassing Context API in Web Layer

```elixir
# AVOID: Web layer bypassing context API
def show(conn, %{"id" => id}) do
  # Directly using Repo and schema in the controller bypasses Content context
  post = BeamFlow.Repo.get!(BeamFlow.Content.Post, id)
  
  render(conn, :show, post: post)
end

# BETTER: Use the context API
def show(conn, %{"id" => id}) do
  case Content.get_post(id) do
    {:ok, post} -> 
      render(conn, :show, post: post)
    {:error, :not_found} ->
      conn
      |> put_flash(:error, "Post not found")
      |> redirect(to: ~p"/posts")
  end
end
```

## Extending Contexts

### When to Create a New Context

Create a new context when:

1. You have a new domain concept that doesn't fit in existing contexts
2. A group of related functionality would benefit from its own API boundary
3. You want to encapsulate a specific external service or integration

### When to Extend an Existing Context

Extend an existing context when:

1. Adding functionality closely related to existing context responsibilities
2. Adding new schemas that relate directly to existing schemas in the context
3. Adding new operations on existing data owned by the context

### Guidelines for Context Size

- Keep contexts focused on a specific domain concept
- If a context grows too large (over ~1000 lines), consider splitting it
- Split based on cohesion—group related functionality together
- Create sub-contexts for large domains (e.g., `Content.Publishing`, `Content.Media`)

## Context Organization Examples

### Basic Context

```
lib/beam_flow/
├── accounts/
│   ├── user.ex             # Schema
│   ├── permission.ex       # Schema
│   └── authentication.ex   # Internal service module
├── accounts.ex             # Public API
```

### Complex Context with Sub-Modules

```
lib/beam_flow/
├── content/
│   ├── post.ex             # Schema
│   ├── category.ex         # Schema
│   ├── tag.ex              # Schema
│   ├── publishing/
│   │   ├── workflow.ex     # Publishing pipeline
│   │   └── scheduler.ex    # Scheduled publishing
│   ├── media/
│   │   ├── attachment.ex   # Schema
│   │   ├── image.ex        # Schema
│   │   └── optimizer.ex    # Image processing
│   └── search/
│       ├── indexer.ex      # Search indexing
│       └── query.ex        # Search query builder
├── content.ex              # Public API
```

## Resources

- [Phoenix Contexts Guide](https://hexdocs.pm/phoenix/contexts.html)
- [Ecto Schema Guide](https://hexdocs.pm/ecto/Ecto.Schema.html)
- [BeamFlow CMS Testing Overview](../testing/overview.md)