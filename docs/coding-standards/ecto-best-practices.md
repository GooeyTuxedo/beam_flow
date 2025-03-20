# Ecto Best Practices for BeamFlow CMS

This document outlines best practices for using Ecto in the BeamFlow CMS project, covering schema design, querying, relationships, changesets, and performance optimization.

## Schema Design

### Schema Structure

Follow a consistent structure for schema modules:

```elixir
defmodule BeamFlow.Content.Post do
  use Ecto.Schema
  import Ecto.Changeset
  alias BeamFlow.Accounts.User
  alias BeamFlow.Content.{Category, Comment, Tag}

  @type t :: %__MODULE__{
    id: Ecto.UUID.t(),
    title: String.t(),
    content: String.t(),
    # ... other fields
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "posts" do
    field :title, :string
    field :slug, :string
    field :content, :string
    field :excerpt, :string
    field :status, :string, default: "draft"
    field :published_at, :utc_datetime
    
    # Virtual fields
    field :word_count, :integer, virtual: true
    
    # Associations
    belongs_to :user, User
    many_to_many :categories, Category, join_through: "post_categories"
    many_to_many :tags, Tag, join_through: "post_tags"
    has_many :comments, Comment
    
    timestamps()
  end
  
  @required_fields [:title, :content]
  @optional_fields [:excerpt, :status, :published_at]
  
  @doc """
  Changeset for creating a new post.
  """
  def changeset(post, attrs) do
    post
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, ["draft", "published", "scheduled"])
    |> generate_slug()
    |> unique_constraint(:slug)
  end
  
  @doc """
  Changeset for publishing a post.
  """
  def publish_changeset(post, attrs) do
    post
    |> cast(attrs, [:status, :published_at])
    |> validate_required([:published_at])
    |> validate_inclusion(:status, ["published"])
  end
  
  # Private functions
  defp generate_slug(%Ecto.Changeset{valid?: true, changes: %{title: title}} = changeset) do
    slug = title |> String.downcase() |> String.replace(~r/[^a-z0-9\s-]/, "") |> String.replace(~r/[\s-]+/, "-")
    put_change(changeset, :slug, slug)
  end
  
  defp generate_slug(changeset), do: changeset
end
```

### Field Types and Constraints

- Use appropriate field types for data:
  - `:string` - For text under 255 characters
  - `:text` - For longer text content
  - `:integer` - For whole numbers
  - `:float` - For decimal numbers
  - `:boolean` - For true/false values
  - `:date` - For dates without time
  - `:time` - For time without date
  - `:naive_datetime` - For timestamps without timezone
  - `:utc_datetime` - For timestamps with UTC timezone
  - `:binary_id` - For UUID primary keys

- Consider database constraints:
  - Use `unique_constraint/3` for fields that must be unique
  - Use `foreign_key_constraint/3` for association integrity
  - Use `check_constraint/3` for complex validations

```elixir
def changeset(post, attrs) do
  post
  |> cast(attrs, [:title, :slug, :user_id])
  |> validate_required([:title, :user_id])
  |> unique_constraint(:slug)
  |> foreign_key_constraint(:user_id)
  |> check_constraint(:title, name: :title_length_must_be_less_than_100)
end
```

## Changesets

### Changeset Best Practices

1. **Split Changesets by Purpose**
   - Create specific changesets for different operations
   - Name changesets based on their purpose

```elixir
# Different changesets for different operations
def create_changeset(post, attrs), do: # ...
def update_changeset(post, attrs), do: # ...
def publish_changeset(post, attrs), do: # ...
```

2. **Validate Data Comprehensively**
   - Use built-in validations for common cases
   - Create custom validations for complex rules

```elixir
def changeset(user, attrs) do
  user
  |> cast(attrs, [:email, :password, :name])
  |> validate_required([:email, :password])
  |> validate_length(:password, min: 8)
  |> validate_format(:email, ~r/@/)
  |> unique_constraint(:email)
  |> put_password_hash()
end
```

3. **Transformation and Defaults**
   - Transform data in changesets with `prepare_changes/2`
   - Set default values with `put_change/3`

```elixir
def changeset(post, attrs) do
  post
  |> cast(attrs, [:title, :content])
  |> validate_required([:title, :content])
  |> prepare_changes(fn changeset ->
      if get_change(changeset, :title) do
        put_change(changeset, :slug, generate_slug(get_change(changeset, :title)))
      else
        changeset
      end
    end)
end
```

4. **Complex Validations**
   - Create custom validation functions for complex rules
   - Make validation errors clear and actionable

```elixir
def changeset(post, attrs) do
  post
  |> cast(attrs, [:scheduled_at, :status])
  |> validate_required([:status])
  |> validate_scheduled_datetime()
end

defp validate_scheduled_datetime(changeset) do
  status = get_field(changeset, :status)
  scheduled_at = get_field(changeset, :scheduled_at)
  
  if status == "scheduled" && is_nil(scheduled_at) do
    add_error(changeset, :scheduled_at, "must be set when status is scheduled")
  else
    changeset
  end
end
```

## Querying

### Query Best Practices

1. **Build Queries Incrementally**
   - Use pipe operator to build complex queries
   - Start with the schema and add conditions

```elixir
def list_published_posts_by_category(category_id, limit \\ 10) do
  Post
  |> where([p], p.status == "published")
  |> join(:inner, [p], pc in "post_categories", on: pc.post_id == p.id)
  |> where([_, pc], pc.category_id == ^category_id)
  |> preload(:user)
  |> order_by([p], desc: p.published_at)
  |> limit(^limit)
  |> Repo.all()
end
```

2. **Use Query Composability**
   - Create reusable query fragments
   - Combine fragments for complex queries

```elixir
# Query fragments
def published(query) do
  query |> where([p], p.status == "published")
end

def with_author(query) do
  query |> preload(:user)
end

def recent(query, limit \\ 10) do
  query
  |> order_by([p], desc: p.published_at)
  |> limit(^limit)
end

# Combined query
def list_recent_published_posts(limit \\ 10) do
  Post
  |> published()
  |> with_author()
  |> recent(limit)
  |> Repo.all()
end
```

3. **Pagination**
   - Implement cursor-based pagination for large datasets
   - Use limit/offset for simple pagination

```elixir
# Offset-based pagination
def paginate_posts(page \\ 1, per_page \\ 20) do
  offset = max(0, (page - 1) * per_page)
  
  posts =
    Post
    |> order_by([p], desc: p.inserted_at)
    |> limit(^per_page)
    |> offset(^offset)
    |> Repo.all()
    
  total = Post |> Repo.aggregate(:count, :id)
  
  %{
    entries: posts,
    page_number: page,
    page_size: per_page,
    total_entries: total,
    total_pages: ceil(total / per_page)
  }
end

# Cursor-based pagination
def paginate_posts_cursor(cursor \\ nil, limit \\ 20) do
  query = from p in Post, order_by: [desc: p.inserted_at], limit: ^limit
  
  query =
    if cursor do
      last_inserted_at = cursor_to_datetime(cursor)
      from p in query, where: p.inserted_at < ^last_inserted_at
    else
      query
    end
    
  posts = Repo.all(query)
  
  last_post = List.last(posts)
  next_cursor = if last_post, do: datetime_to_cursor(last_post.inserted_at), else: nil
  
  %{
    entries: posts,
    next_cursor: next_cursor,
    has_more: length(posts) == limit
  }
end
```

4. **Preloading Associations**
   - Preload associations to avoid N+1 queries
   - Use selective preloading for specific needs

```elixir
# Preload in the main query
posts =
  Post
  |> where(status: "published")
  |> preload([:user, :categories, comments: :user])
  |> Repo.all()

# Preload separately
posts = Repo.all(from p in Post, where: p.status == "published")
posts_with_data = Repo.preload(posts, [:user, :categories, comments: :user])

# Preload with custom query
posts = Repo.all(from p in Post, where: p.status == "published")
posts_with_comments = 
  Repo.preload(posts, [comments: from(c in Comment, order_by: [desc: c.inserted_at], limit: 5)])
```

## Associations

### Association Best Practices

1. **Choose the Right Association Type**
   - `belongs_to` - Child side of a one-to-many
   - `has_many` - Parent side of a one-to-many
   - `has_one` - Parent side of a one-to-one
   - `many_to_many` - Many-to-many relationship

2. **Handle Associations in Changesets**
   - Use `put_assoc/4` for has_one/has_many
   - Use `cast_assoc/3` for nested forms
   - Use `put_change/3` for belongs_to

```elixir
# Handling belongs_to
def create_changeset(post, attrs, user) do
  post
  |> cast(attrs, [:title, :content])
  |> validate_required([:title, :content])
  |> put_change(:user_id, user.id)
end

# Handling has_many with put_assoc
def create_changeset(post, attrs, categories) do
  post
  |> cast(attrs, [:title, :content])
  |> validate_required([:title, :content])
  |> put_assoc(:categories, categories)
end

# Handling nested associations with cast_assoc
def create_changeset(post, attrs) do
  post
  |> cast(attrs, [:title, :content])
  |> validate_required([:title, :content])
  |> cast_assoc(:comments, with: &Comment.changeset/2)
end
```

3. **Managing many_to_many Relationships**
   - Use join schemas for additional join table fields
   - Use `put_assoc/4` for simple many_to_many

```elixir
# Using join_through with a string (simple)
schema "posts" do
  # ...
  many_to_many :tags, Tag, join_through: "post_tags"
end

# Using join_through with a schema (complex)
schema "posts" do
  # ...
  many_to_many :categories, Category, join_through: PostCategory
end

# PostCategory schema for extra join fields
defmodule BeamFlow.Content.PostCategory do
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key false
  schema "post_categories" do
    belongs_to :post, Post
    belongs_to :category, Category
    field :featured, :boolean, default: false
    
    timestamps()
  end
  
  def changeset(post_category, attrs) do
    post_category
    |> cast(attrs, [:post_id, :category_id, :featured])
    |> validate_required([:post_id, :category_id])
    |> unique_constraint([:post_id, :category_id])
  end
end
```

## Performance Optimization

### N+1 Query Prevention

The N+1 query problem is a common performance issue where an application makes N additional queries for N records fetched in an initial query.

```elixir
# BAD: N+1 query problem
posts = Content.list_posts()

# This triggers a query for each post
Enum.each(posts, fn post ->
  author = Accounts.get_user!(post.user_id)
  IO.puts("#{post.title} by #{author.name}")
end)

# GOOD: Using preload to avoid N+1
posts =
  Post
  |> Repo.all()
  |> Repo.preload(:user)

Enum.each(posts, fn post ->
  IO.puts("#{post.title} by #{post.user.name}")
end)
```

### Efficient Bulk Operations

For bulk operations, use Ecto's bulk insert and update features:

```elixir
# Efficient bulk insert
entries = [
  %{title: "Post 1", user_id: user_id},
  %{title: "Post 2", user_id: user_id},
  # ...
]

Repo.insert_all(Post, entries)

# Using multi for transactional operations
alias Ecto.Multi

def publish_multiple_posts(post_ids, attrs) do
  posts = Repo.all(from p in Post, where: p.id in ^post_ids)
  
  Multi.new()
  |> Multi.update_all(:published, 
    from(p in Post, where: p.id in ^post_ids),
    set: [status: "published", published_at: DateTime.utc_now()]
  )
  |> Multi.insert_all(:activities, Activity, 
    Enum.map(posts, fn post -> 
      %{post_id: post.id, action: "publish", performed_at: DateTime.utc_now()}
    end)
  )
  |> Repo.transaction()
end
```

### Indexing Strategies

Ensure proper database indexes are created:

```elixir
# In a migration
def change do
  create index(:posts, [:status])
  create index(:posts, [:user_id])
  create unique_index(:posts, [:slug])
  create index(:posts, [:published_at])
  create index(:comments, [:post_id, :inserted_at])
end
```

### Query Optimization Techniques

1. **Select Only Needed Fields**
   - Use `select/3` to fetch only required fields
   - Create specific structs for query responses

```elixir
def get_post_titles() do
  query = 
    from p in Post,
    select: %{id: p.id, title: p.title}
  
  Repo.all(query)
end

def get_post_statistics() do
  query =
    from p in Post,
    group_by: p.status,
    select: {p.status, count(p.id)}
  
  Repo.all(query)
end
```

2. **Use Database Functions**
   - Leverage database functions for calculations
   - Use `fragment/1` for database-specific features

```elixir
def search_posts(term) do
  search_term = "%#{term}%"
  
  from p in Post,
    where: ilike(p.title, ^search_term) or ilike(p.content, ^search_term),
    order_by: [desc: fragment("similarity(?, ?)", p.title, ^term)]
end

def get_post_with_word_count(id) do
  from p in Post,
    where: p.id == ^id,
    select: %{
      id: p.id,
      title: p.title,
      content: p.content,
      word_count: fragment("array_length(regexp_split_to_array(?, E'\\\\s+'), 1)", p.content)
    }
end
```

## Transactions and Concurrency

### Transaction Best Practices

1. **Use Multi for Complex Transactions**
   - Group related operations with `Ecto.Multi`
   - Handle transaction results properly

```elixir
def publish_post_with_notification(post, attrs) do
  Multi.new()
  |> Multi.update(:post, Post.publish_changeset(post, attrs))
  |> Multi.insert(:activity, fn %{post: updated_post} -> 
      Activity.changeset(%Activity{}, %{
        post_id: updated_post.id,
        action: "publish"
      })
    end)
  |> Multi.insert(:notification, fn %{post: updated_post} ->
      Notification.changeset(%Notification{}, %{
        title: "New post published",
        content: "#{updated_post.title} has been published",
        type: "post_published"
      })
    end)
  |> Repo.transaction()
  |> case do
    {:ok, %{post: post, activity: _activity, notification: notification}} ->
      send_notification(notification)
      {:ok, post}
      
    {:error, failed_operation, failed_value, _changes_so_far} ->
      {:error, {failed_operation, failed_value}}
  end
end
```

2. **Handle Concurrency with Optimistic Locking**
   - Use version fields to prevent conflicts
   - Handle stale data errors gracefully

```elixir
# Add version field to schema
schema "posts" do
  # ...
  field :version, :integer, default: 1
end

# In the changeset
def update_changeset(post, attrs) do
  post
  |> cast(attrs, [:title, :content])
  |> validate_required([:title, :content])
  |> optimistic_lock(:version)
end

# Handle StaleEntryError
def update_post(id, attrs) do
  post = Repo.get!(Post, id)
  
  try do
    post
    |> Post.update_changeset(attrs)
    |> Repo.update()
  rescue
    Ecto.StaleEntryError ->
      {:error, :conflict}
  end
end
```

## Testing with Ecto

Refer to our [Testing Overview](../testing/overview.md) for comprehensive guidance on testing Ecto code.

## Resources

- [Ecto Documentation](https://hexdocs.pm/ecto/Ecto.html)
- [Ecto SQL Documentation](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.html)
- [Phoenix Contexts Guide](https://hexdocs.pm/phoenix/contexts.html)
- [BeamFlow CMS Testing Overview](../testing/overview.md)