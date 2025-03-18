defmodule BeamFlow.Content do
  @moduledoc """
  The Content context handles all content-related operations,
  including posts, categories, and tags.
  """

  import Ecto.Changeset, only: [put_change: 3, get_field: 2]
  import Ecto.Query, warn: false

  alias BeamFlow.Content.Post
  alias BeamFlow.Repo
  alias BeamFlow.Utils.Slugifier

  @doc """
  Returns a list of posts.

  ## Examples

      iex> list_posts()
      [%Post{}, ...]

  """
  def list_posts do
    Post
    |> Repo.all()
    |> Repo.preload(:user)
  end

  @doc """
  Returns a list of posts matching the given criteria.

  ## Examples

      iex> list_posts(status: "published")
      [%Post{}, ...]

  """
  def list_posts(criteria) do
    query = from(p in Post)

    query =
      Enum.reduce(criteria, query, fn
        {:status, status}, query ->
          from q in query, where: q.status == ^status

        {:user_id, user_id}, query ->
          from q in query, where: q.user_id == ^user_id

        {:search, search_term}, query ->
          search_term = "%#{search_term}%"

          from q in query,
            where:
              ilike(q.title, ^search_term) or
                ilike(q.content, ^search_term) or
                ilike(q.excerpt, ^search_term)

        {:order_by, {field, direction}}, query ->
          from q in query, order_by: [{^direction, ^field}]

        {:limit, limit}, query ->
          from q in query, limit: ^limit

        _query, query ->
          query
      end)

    query
    |> Repo.all()
    |> Repo.preload(:user)
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
    Post
    |> Repo.get!(id)
    |> Repo.preload(:user)
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
    Post
    |> Repo.get_by(slug: slug)
    |> Repo.preload(:user)
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
    %Post{}
    |> Post.create_changeset(attrs)
    |> ensure_unique_slug()
    |> Repo.insert()
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
    post
    |> Post.changeset(attrs)
    |> ensure_unique_slug()
    |> Repo.update()
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
    Repo.delete(post)
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
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    update_post(post, %{status: "published", published_at: now})
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
