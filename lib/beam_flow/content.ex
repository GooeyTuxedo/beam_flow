defmodule BeamFlow.Content do
  @moduledoc """
  The Content context handles all content-related operations,
  including posts, categories, and tags.
  """

  import Ecto.Changeset, only: [put_change: 3, get_field: 2]
  import Ecto.Query, warn: false

  require BeamFlow.Tracer
  require OpenTelemetry.Tracer

  alias BeamFlow.Content.Post
  alias BeamFlow.Repo
  alias BeamFlow.Tracer
  alias BeamFlow.Utils.Slugifier

  @doc """
  Returns a list of posts.

  ## Examples

      iex> list_posts()
      [%Post{}, ...]

  """
  def list_posts do
    Tracer.with_span "content.list_posts" do
      Post
      |> Repo.all()
      |> Repo.preload(:user)
    end
  end

  @doc """
  Returns a list of posts matching the given criteria.

  ## Examples

      iex> list_posts(status: "published")
      [%Post{}, ...]

  """
  def list_posts(criteria) do
    Tracer.with_span "content.list_posts.filtered", %{
      criteria_count: length(criteria)
    } do
      query = from(p in Post)

      query =
        Enum.reduce(criteria, query, fn
          {:status, status}, query ->
            Tracer.add_event("filter.status", %{status: status})
            from q in query, where: q.status == ^status

          {:user_id, user_id}, query ->
            Tracer.add_event("filter.user_id", %{user_id: user_id})
            from q in query, where: q.user_id == ^user_id

          {:search, search_term}, query ->
            Tracer.add_event("filter.search", %{term: search_term})
            search_term = "%#{search_term}%"

            from q in query,
              where:
                ilike(q.title, ^search_term) or
                  ilike(q.content, ^search_term) or
                  ilike(q.excerpt, ^search_term)

          {:order_by, {field, direction}}, query ->
            Tracer.add_event("filter.order_by", %{field: field, direction: direction})
            from q in query, order_by: [{^direction, ^field}]

          {:limit, limit}, query ->
            Tracer.add_event("filter.limit", %{limit: limit})
            from q in query, limit: ^limit

          _query, query ->
            query
        end)

      results =
        query
        |> Repo.all()
        |> Repo.preload(:user)

      Tracer.set_attributes(%{result_count: length(results)})
      results
    end
  end

  @doc """
  Gets a single post by ID.

  Raises `Ecto.NoResultsError` if the Post does not exist.

  ## Examples

      iex> get_post!(123)
      %Post{}

      iex> get_post!(456)
      ** (Ecto.NoResultsError)

  """
  def get_post!(id) do
    Tracer.with_span "content.get_post", %{post_id: id} do
      Post
      |> Repo.get!(id)
      |> Repo.preload(:user)
    end
  rescue
    e in Ecto.NoResultsError ->
      Tracer.set_error("Post not found")
      Tracer.record_exception(e, __STACKTRACE__)
      reraise e, __STACKTRACE__
  end

  @doc """
  Gets a single post by slug.

  Returns nil if the Post does not exist.

  ## Examples

      iex> get_post_by_slug("my-post")
      %Post{}

      iex> get_post_by_slug("nonexistent")
      nil

  """
  def get_post_by_slug(slug) do
    Tracer.with_span "content.get_post_by_slug", %{slug: slug} do
      result =
        Post
        |> Repo.get_by(slug: slug)
        |> Repo.preload(:user)

      if result do
        Tracer.add_event("post.found", %{id: result.id})
      else
        Tracer.add_event("post.not_found", %{})
      end

      result
    end
  end

  @doc """
  Creates a post.

  ## Examples

      iex> create_post(%{field: value})
      {:ok, %Post{}}

      iex> create_post(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_post(attrs \\ %{}) do
    Tracer.with_span "content.create_post" do
      # Extract useful attributes for tracing
      title = Map.get(attrs, "title", Map.get(attrs, :title, "unknown"))
      user_id = Map.get(attrs, "user_id", Map.get(attrs, :user_id))
      status = Map.get(attrs, "status", Map.get(attrs, :status, "draft"))

      Tracer.set_attributes(%{
        title: title,
        user_id: user_id,
        status: status
      })

      %Post{}
      |> Post.create_changeset(attrs)
      |> ensure_unique_slug()
      |> Repo.insert()
      |> case do
        {:ok, post} ->
          Tracer.add_event("post.created", %{id: post.id, slug: post.slug})
          {:ok, Repo.preload(post, :user)}

        {:error, changeset} ->
          Tracer.add_event("post.validation_failed", %{
            errors: inspect(changeset.errors)
          })

          Tracer.set_error("Validation failed")
          {:error, changeset}
      end
    end
  end

  @doc """
  Updates a post.

  ## Examples

      iex> update_post(post, %{field: new_value})
      {:ok, %Post{}}

      iex> update_post(post, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_post(%Post{} = post, attrs) do
    Tracer.with_span "content.update_post", %{post_id: post.id} do
      Tracer.add_event("post.update_started", %{
        title: Map.get(attrs, "title", Map.get(attrs, :title, post.title)),
        status: Map.get(attrs, "status", Map.get(attrs, :status, post.status))
      })

      post
      |> Post.changeset(attrs)
      |> ensure_unique_slug()
      |> Repo.update()
      |> case do
        {:ok, updated_post} ->
          Tracer.add_event("post.updated", %{slug: updated_post.slug})
          {:ok, Repo.preload(updated_post, :user)}

        {:error, changeset} ->
          Tracer.add_event("post.update_failed", %{
            errors: inspect(changeset.errors)
          })

          Tracer.set_error("Update validation failed")
          {:error, changeset}
      end
    end
  end

  @doc """
  Deletes a post.

  ## Examples

      iex> delete_post(post)
      {:ok, %Post{}}

      iex> delete_post(post)
      {:error, %Ecto.Changeset{}}

  """
  def delete_post(%Post{} = post) do
    Tracer.with_span "content.delete_post", %{post_id: post.id, title: post.title} do
      case Repo.delete(post) do
        {:ok, deleted_post} ->
          Tracer.add_event("post.deleted", %{})
          {:ok, deleted_post}

        {:error, changeset} ->
          Tracer.add_event("post.delete_failed", %{
            errors: inspect(changeset.errors)
          })

          Tracer.set_error("Delete failed")
          {:error, changeset}
      end
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking post changes.

  ## Examples

      iex> change_post(post)
      %Ecto.Changeset{data: %Post{}}

  """
  def change_post(%Post{} = post, attrs \\ %{}) do
    Post.changeset(post, attrs)
  end

  @doc """
  Publishes a post immediately.

  ## Examples

      iex> publish_post(post)
      {:ok, %Post{}}

  """
  def publish_post(%Post{} = post) do
    Tracer.with_span "content.publish_post", %{post_id: post.id, title: post.title} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Tracer.add_event("post.publishing", %{publish_time: now})

      case update_post(post, %{status: "published", published_at: now}) do
        {:ok, _published_post} = result ->
          Tracer.add_event("post.published", %{})
          result

        {:error, _no_post} = error ->
          Tracer.set_error("Failed to publish post")
          error
      end
    end
  end

  # Ensures a slug is unique by appending a counter if necessary.
  defp ensure_unique_slug(changeset) do
    case get_field(changeset, :slug) do
      nil ->
        changeset

      slug ->
        # Generate a unique slug
        unique_slug = Slugifier.ensure_unique_slug(slug, &slug_exists?(&1, changeset))

        if slug != unique_slug do
          Tracer.add_event("slug.modified", %{
            original: slug,
            modified: unique_slug
          })

          put_change(changeset, :slug, unique_slug)
        else
          changeset
        end
    end
  end

  # Check if a slug exists, excluding the current entity if it exists
  defp slug_exists?(test_slug, changeset) do
    query = from p in Post, where: p.slug == ^test_slug
    query = exclude_current_post(query, changeset)
    Repo.exists?(query)
  end

  # Exclude the current post when checking uniqueness during updates
  defp exclude_current_post(query, changeset) do
    case get_field(changeset, :id) do
      nil -> query
      id -> from p in query, where: p.id != ^id
    end
  end
end
