# Phoenix LiveView Best Practices for BeamFlow CMS

This guide outlines best practices for developing with Phoenix LiveView in the BeamFlow CMS project. Following these guidelines ensures consistent, maintainable, and performant LiveView components.

## Core Principles

1. **Server State Minimalism**: Keep only necessary data in LiveView state
2. **Component Composition**: Break UI into reusable LiveComponent modules
3. **Optimistic UI Updates**: Update UI before server processing completes
4. **Progressive Enhancement**: Ensure basic functionality works without JS
5. **Proper Event Handling**: Use correct event handlers for different scenarios

## LiveView Module Structure

Follow a consistent structure for LiveView modules:

```elixir
defmodule BeamFlowWeb.PostLive.Index do
  use BeamFlowWeb, :live_view
  
  alias BeamFlow.Content
  alias BeamFlow.Content.Post
  
  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    if connected?(socket), do: Content.subscribe()
    
    socket = assign_defaults(socket, session)
    posts = Content.list_posts_for_user(socket.assigns.current_user)
    
    {:ok, assign(socket, posts: posts, page_title: "Posts")}
  end
  
  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end
  
  @impl Phoenix.LiveView
  def handle_event("delete", %{"id" => id}, socket) do
    post = Content.get_post!(id)
    
    case Content.delete_post(socket.assigns.current_user, post) do
      {:ok, _} ->
        {:noreply, 
          socket
          |> put_flash(:info, "Post deleted successfully")
          |> push_navigate(to: ~p"/posts")}
          
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete post")}
    end
  end
  
  @impl Phoenix.LiveView
  def handle_info({:post_created, post}, socket) do
    {:noreply, update(socket, :posts, fn posts -> [post | posts] end)}
  end
  
  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Post")
    |> assign(:post, Content.get_post!(id))
  end
  
  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Post")
    |> assign(:post, %Post{})
  end
  
  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Posts")
    |> assign(:post, nil)
  end
  
  defp assign_defaults(socket, session) do
    assign_new(socket, :current_user, fn -> 
      Accounts.get_user!(session["user_id"])
    end)
  end
end
```

## LiveView Best Practices

### Mounting and State Management

1. **Check for Connection Status**:
   - Use `connected?(socket)` to differentiate between the initial HTTP request and WebSocket connection.
   - Only subscribe to PubSub topics when the socket is connected.

```elixir
@impl Phoenix.LiveView
def mount(_params, _session, socket) do
  if connected?(socket), do: Content.subscribe()
  # ...
end
```

2. **Load Data Efficiently**:
   - Load minimal data on initial mount
   - Use phased loading for complex views

```elixir
# Phased loading approach
def mount(_params, _session, socket) do
  # Initial state with loading indicator
  socket = assign(socket, loading: true, posts: [])
  
  if connected?(socket) do
    send(self(), :load_posts)
  end
  
  {:ok, socket}
end

def handle_info(:load_posts, socket) do
  posts = Content.list_posts_for_user(socket.assigns.current_user)
  {:noreply, assign(socket, loading: false, posts: posts)}
end
```

3. **Assign Default Values Safely**:
   - Use `assign_new/3` for values that should only be computed once

```elixir
def mount(_params, session, socket) do
  socket =
    socket
    |> assign_new(:current_user, fn -> get_current_user(session) end)
    |> assign_new(:timezone, fn -> get_user_timezone(socket.assigns.current_user) end)
  
  {:ok, socket}
end
```

### LiveView Events

1. **Use the Right Event Handlers**:
   - `handle_event/3` - Client-side events (clicks, form submissions)
   - `handle_info/2` - Server-side messages (PubSub, processes)
   - `handle_params/3` - URL parameters

2. **Provide Immediate Feedback**:
   - Update UI optimistically before server processing completes
   - Show loading states for longer operations

```elixir
def handle_event("like", %{"id" => id}, socket) do
  # Optimistic UI update
  socket = update(socket, :posts, fn posts ->
    Enum.map(posts, fn
      %{id: ^id} = post -> %{post | likes: post.likes + 1, liked_by_user: true}
      post -> post
    end)
  end)
  
  # Actual server processing
  spawn(fn -> Content.like_post(socket.assigns.current_user, id) end)
  
  {:noreply, socket}
end
```

3. **Form Handling**:
   - Use `phx-change` for real-time validation
   - Use `phx-submit` for form submission
   - Validate both client-side and server-side

```elixir
def handle_event("validate", %{"post" => post_params}, socket) do
  changeset =
    socket.assigns.post
    |> Content.change_post(post_params)
    |> Map.put(:action, :validate)
    
  {:noreply, assign(socket, :changeset, changeset)}
end

def handle_event("save", %{"post" => post_params}, socket) do
  save_post(socket, socket.assigns.live_action, post_params)
end

defp save_post(socket, :new, post_params) do
  case Content.create_post(socket.assigns.current_user, post_params) do
    {:ok, _post} ->
      {:noreply,
        socket
        |> put_flash(:info, "Post created successfully")
        |> push_navigate(to: ~p"/posts")}
        
    {:error, %Ecto.Changeset{} = changeset} ->
      {:noreply, assign(socket, changeset: changeset)}
  end
end
```

### LiveComponents

1. **When to Use LiveComponents**:
   - Stateful components that need their own lifecycle
   - Reusable UI elements that appear multiple times on a page
   - Complex forms or UI widgets

2. **Stateless Components vs. LiveComponents**:
   - Use function components for stateless UI elements
   - Use LiveComponents for stateful or interactive elements

```elixir
# Function component (stateless)
def post_card(assigns) do
  ~H"""
  <div class="post-card">
    <h3><%= @post.title %></h3>
    <div class="post-excerpt"><%= @post.excerpt %></div>
  </div>
  """
end

# Live component (stateful)
defmodule BeamFlowWeb.PostLive.CommentComponent do
  use BeamFlowWeb, :live_component
  
  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id={"comment-#{@comment.id}"}>
      <p><%= @comment.content %></p>
      <button phx-click="like" phx-target={@myself}>
        Like (<%= @comment.likes %>)
      </button>
    </div>
    """
  end
  
  @impl Phoenix.LiveComponent
  def handle_event("like", _, socket) do
    comment = socket.assigns.comment
    updated_comment = %{comment | likes: comment.likes + 1}
    
    {:noreply, assign(socket, :comment, updated_comment)}
  end
end
```

3. **Component Communication**:
   - Parent to child: Pass data via assigns
   - Child to parent: Use events with `phx-target`
   - Cross-component: Use PubSub or parent coordination

```elixir
# Parent LiveView
def handle_event("comment_liked", %{"id" => id}, socket) do
  # Update parent state when child sends event
  {:noreply, update_comment_likes(socket, id)}
end

# In the template
<.live_component
  module={CommentComponent}
  id={"comment-#{comment.id}"}
  comment={comment}
/>
  
# Child component
def handle_event("like", _, socket) do
  # Send event to parent
  send_update_after(
    __MODULE__,
    %{id: socket.assigns.id, comment: updated_comment},
    100
  )
  
  # Also notify parent
  send(self(), {:comment_updated, updated_comment})
  
  {:noreply, socket}
end
```

### Performance Optimization

1. **Minimize Assigns**:
   - Only keep necessary data in socket assigns
   - Use `update/3` for targeted updates

2. **Reduce DOM Updates**:
   - Use `phx-update="replace"` for large content changes
   - Use `phx-update="append"` or `phx-update="prepend"` for list modifications

```html
<div id="posts" phx-update="append">
  <%= for post <- @posts do %>
    <div id={"post-#{post.id}"} class="post">
      <%= post.title %>
    </div>
  <% end %>
</div>
```

3. **Optimize Re-renders**:
   - Use temporary assigns for large lists that don't need to be re-rendered
   - Use the `stream/3` API for efficient list management

```elixir
def mount(_params, _session, socket) do
  posts = Content.list_recent_posts()
  
  socket =
    socket
    |> stream(:posts, posts)
    |> assign(:page_title, "Recent Posts")
    
  {:ok, socket}
end

def handle_event("load_more", _params, socket) do
  %{entries: entries, metadata: metadata} = socket.assigns.posts
  
  if metadata.has_next do
    {:page, current_page} = metadata.after
    new_page = current_page + 1
    more_posts = Content.list_posts(page: new_page)
    
    {:noreply, stream_append(socket, :posts, more_posts)}
  else
    {:noreply, socket}
  end
end
```

4. **Lazy Loading**:
   - Load data only when needed
   - Use pagination or infinite scrolling for large datasets

```elixir
# In the template
<div id="infinite-scroll" phx-hook="InfiniteScroll">
  <%= for post <- @posts do %>
    <!-- post content -->
  <% end %>
  
  <%= if @has_more do %>
    <div class="loader">Loading more...</div>
  <% end %>
</div>

# In hooks.js
let InfiniteScroll = {
  mounted() {
    this.observer = new IntersectionObserver(entries => {
      if (entries[0].isIntersecting) {
        this.pushEvent("load_more", {})
      }
    })
    
    this.observer.observe(this.el.querySelector(".loader"))
  },
  destroyed() {
    this.observer.disconnect()
  }
}
```

### Security Considerations

1. **Validate All Input**:
   - Validate form data both client-side and server-side
   - Use changesets for data validation

2. **Authorize Actions**:
   - Check user permissions before performing actions
   - Validate that the user has access to the requested resources

```elixir
def handle_event("delete", %{"id" => id}, socket) do
  user = socket.assigns.current_user
  post = Content.get_post!(id)
  
  case Content.authorize(user, post, :delete) do
    :ok ->
      case Content.delete_post(post) do
        {:ok, _} -> {:noreply, put_flash(socket, :info, "Post deleted")}
        {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to delete")}
      end
      
    {:error, :unauthorized} ->
      {:noreply, put_flash(socket, :error, "Not authorized")}
  end
end
```

3. **Prevent Common Vulnerabilities**:
   - Use `Phoenix.HTML.Tag` helpers to prevent XSS
   - Use rate limiting for form submissions and actions

## Testing LiveView

Refer to our [LiveView Testing Guide](../testing/liveflow-tests.md) for comprehensive guidance on testing LiveView components.

## Resources

- [Phoenix LiveView Documentation](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html)
- [LiveView Testing Guide](./docs/testing/liveflow-tests.md)
- [Phoenix LiveView Best Practices](https://hexdocs.pm/phoenix_live_view/security-model.html)