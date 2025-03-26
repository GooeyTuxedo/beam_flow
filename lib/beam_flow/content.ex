defmodule BeamFlow.Content do
  @moduledoc """
  The Content context handles all content-related operations,
  including posts, categories, and tags.
  """

  import Ecto.Changeset, only: [put_change: 3, get_field: 2]
  import Ecto.Query, warn: false

  require BeamFlow.Tracer
  require OpenTelemetry.Tracer

  alias BeamFlow.Content.Category
  alias BeamFlow.Content.Media
  alias BeamFlow.Content.MediaStorage
  alias BeamFlow.Content.Post
  alias BeamFlow.Content.Tag
  alias BeamFlow.Repo
  alias BeamFlow.Tracer
  alias BeamFlow.Utils.Slugifier

  #
  # Post operations
  #

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
      |> Repo.preload([:user, :categories, :tags, :featured_image])
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
        |> Repo.preload([:user, :categories, :tags, :featured_image])

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
      |> Repo.preload([:user, :categories, :tags, :featured_image])
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
        |> Repo.preload([:user, :categories, :tags, :featured_image])

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
          {:ok, Repo.preload(post, [:user, :categories, :tags, :featured_image])}

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
          {:ok, Repo.preload(updated_post, [:user, :categories, :tags, :featured_image])}

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

  #
  # Category operations
  #

  @doc """
  Returns a list of categories.

  ## Examples

      iex> list_categories()
      [%Category{}, ...]

  """
  def list_categories(opts \\ []) do
    Tracer.with_span "content.list_categories" do
      order_by = Keyword.get(opts, :order_by, asc: :name)

      Category
      |> order_by(^order_by)
      |> Repo.all()
    end
  end

  @doc """
  Gets a single category by ID.

  Raises `Ecto.NoResultsError` if the Category does not exist.

  ## Examples

      iex> get_category!(123)
      %Category{}

      iex> get_category!(456)
      ** (Ecto.NoResultsError)

  """
  def get_category!(id) do
    Tracer.with_span "content.get_category", %{category_id: id} do
      Category
      |> Repo.get!(id)
    end
  rescue
    e in Ecto.NoResultsError ->
      Tracer.set_error("Category not found")
      Tracer.record_exception(e, __STACKTRACE__)
      reraise e, __STACKTRACE__
  end

  @doc """
  Gets a single category by slug.

  Returns nil if the Category does not exist.

  ## Examples

      iex> get_category_by_slug("technology")
      %Category{}

      iex> get_category_by_slug("nonexistent")
      nil

  """
  def get_category_by_slug(slug) do
    Tracer.with_span "content.get_category_by_slug", %{slug: slug} do
      result = Category |> Repo.get_by(slug: slug)

      if result do
        Tracer.add_event("category.found", %{id: result.id})
      else
        Tracer.add_event("category.not_found", %{})
      end

      result
    end
  end

  @doc """
  Creates a category.

  ## Examples

      iex> create_category(%{field: value})
      {:ok, %Category{}}

      iex> create_category(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_category(attrs \\ %{}) do
    Tracer.with_span "content.create_category" do
      name = Map.get(attrs, "name", Map.get(attrs, :name, "unknown"))
      current_user = Map.get(attrs, :current_user)

      Tracer.set_attributes(%{name: name})

      %Category{}
      |> Category.changeset(attrs)
      |> ensure_unique_category_slug()
      |> Repo.insert()
      |> tap(fn
        {:ok, category} ->
          Tracer.add_event("category.created", %{id: category.id, slug: category.slug})
          BeamFlow.Logger.audit("category.created", current_user, %{category_id: category.id})

        {:error, changeset} ->
          Tracer.add_event("category.validation_failed", %{errors: inspect(changeset.errors)})
          Tracer.set_error("Validation failed")
      end)
    end
  end

  @doc """
  Updates a category.

  ## Examples

      iex> update_category(category, %{field: new_value})
      {:ok, %Category{}}

      iex> update_category(category, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_category(%Category{} = category, attrs) do
    Tracer.with_span "content.update_category", %{category_id: category.id} do
      current_user = Map.get(attrs, :current_user)

      Tracer.add_event("category.update_started", %{
        name: Map.get(attrs, "name", Map.get(attrs, :name, category.name))
      })

      category
      |> Category.changeset(attrs)
      |> ensure_unique_category_slug()
      |> Repo.update()
      |> tap(fn
        {:ok, updated_category} ->
          Tracer.add_event("category.updated", %{slug: updated_category.slug})
          BeamFlow.Logger.audit("category.updated", current_user, %{category_id: category.id})

        {:error, changeset} ->
          Tracer.add_event("category.update_failed", %{errors: inspect(changeset.errors)})
          Tracer.set_error("Update validation failed")
      end)
    end
  end

  @doc """
  Deletes a category.

  ## Examples

      iex> delete_category(category)
      {:ok, %Category{}}

      iex> delete_category(category)
      {:error, %Ecto.Changeset{}}

  """
  def delete_category(%Category{} = category) do
    Tracer.with_span "content.delete_category", %{category_id: category.id, name: category.name} do
      result = Repo.delete(category)

      tap(result, fn
        {:ok, _changeset} ->
          Tracer.add_event("category.deleted", %{})
          BeamFlow.Logger.audit("category.deleted", nil, %{category_id: category.id})

        {:error, changeset} ->
          Tracer.add_event("category.delete_failed", %{errors: inspect(changeset.errors)})
          Tracer.set_error("Delete failed")
      end)
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking category changes.

  ## Examples

      iex> change_category(category)
      %Ecto.Changeset{data: %Category{}}

  """
  def change_category(%Category{} = category, attrs \\ %{}) do
    Category.changeset(category, attrs)
  end

  def list_posts_by_category(%Category{} = category) do
    Tracer.with_span "content.list_posts_by_category", %{category_id: category.id} do
      category = Repo.preload(category, :posts)
      category.posts
    end
  end

  #
  # Tag operations
  #

  @doc """
  Returns a list of tags.

  ## Examples

      iex> list_tags()
      [%Tag{}, ...]

  """
  def list_tags(opts \\ []) do
    Tracer.with_span "content.list_tags" do
      order_by = Keyword.get(opts, :order_by, asc: :name)

      Tag
      |> order_by(^order_by)
      |> Repo.all()
    end
  end

  @doc """
  Gets a single tag by ID.

  Raises `Ecto.NoResultsError` if the Tag does not exist.

  ## Examples

      iex> get_tag!(123)
      %Tag{}

      iex> get_tag!(456)
      ** (Ecto.NoResultsError)

  """
  def get_tag!(id) do
    Tracer.with_span "content.get_tag", %{tag_id: id} do
      Tag
      |> Repo.get!(id)
    end
  rescue
    e in Ecto.NoResultsError ->
      Tracer.set_error("Tag not found")
      Tracer.record_exception(e, __STACKTRACE__)
      reraise e, __STACKTRACE__
  end

  @doc """
  Gets a single tag by slug.

  Returns nil if the Tag does not exist.

  ## Examples

      iex> get_tag_by_slug("elixir")
      %Tag{}

      iex> get_tag_by_slug("nonexistent")
      nil

  """
  def get_tag_by_slug(slug) do
    Tracer.with_span "content.get_tag_by_slug", %{slug: slug} do
      result = Tag |> Repo.get_by(slug: slug)

      if result do
        Tracer.add_event("tag.found", %{id: result.id})
      else
        Tracer.add_event("tag.not_found", %{})
      end

      result
    end
  end

  @doc """
  Creates a tag.

  ## Examples

      iex> create_tag(%{field: value})
      {:ok, %Tag{}}

      iex> create_tag(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_tag(attrs \\ %{}) do
    Tracer.with_span "content.create_tag" do
      name = Map.get(attrs, "name", Map.get(attrs, :name, "unknown"))
      current_user = Map.get(attrs, :current_user)

      Tracer.set_attributes(%{name: name})

      %Tag{}
      |> Tag.changeset(attrs)
      |> ensure_unique_tag_slug()
      |> Repo.insert()
      |> tap(fn
        {:ok, tag} ->
          Tracer.add_event("tag.created", %{id: tag.id, slug: tag.slug})
          BeamFlow.Logger.audit("tag.created", current_user, %{tag_id: tag.id})

        {:error, changeset} ->
          Tracer.add_event("tag.validation_failed", %{errors: inspect(changeset.errors)})
          Tracer.set_error("Validation failed")
      end)
    end
  end

  @doc """
  Updates a tag.

  ## Examples

      iex> update_tag(tag, %{field: new_value})
      {:ok, %Tag{}}

      iex> update_tag(tag, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_tag(%Tag{} = tag, attrs) do
    Tracer.with_span "content.update_tag", %{tag_id: tag.id} do
      current_user = Map.get(attrs, :current_user)

      Tracer.add_event("tag.update_started", %{
        name: Map.get(attrs, "name", Map.get(attrs, :name, tag.name))
      })

      tag
      |> Tag.changeset(attrs)
      |> ensure_unique_tag_slug()
      |> Repo.update()
      |> tap(fn
        {:ok, updated_tag} ->
          Tracer.add_event("tag.updated", %{slug: updated_tag.slug})
          BeamFlow.Logger.audit("tag.updated", current_user, %{tag_id: tag.id})

        {:error, changeset} ->
          Tracer.add_event("tag.update_failed", %{errors: inspect(changeset.errors)})
          Tracer.set_error("Update validation failed")
      end)
    end
  end

  @doc """
  Deletes a tag.

  ## Examples

      iex> delete_tag(tag)
      {:ok, %Tag{}}

      iex> delete_tag(tag)
      {:error, %Ecto.Changeset{}}

  """
  def delete_tag(%Tag{} = tag) do
    Tracer.with_span "content.delete_tag", %{tag_id: tag.id, name: tag.name} do
      result = Repo.delete(tag)

      tap(result, fn
        {:ok, _changeset} ->
          Tracer.add_event("tag.deleted", %{})
          BeamFlow.Logger.audit("tag.deleted", nil, %{tag_id: tag.id})

        {:error, changeset} ->
          Tracer.add_event("tag.delete_failed", %{errors: inspect(changeset.errors)})
          Tracer.set_error("Delete failed")
      end)
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking tag changes.

  ## Examples

      iex> change_tag(tag)
      %Ecto.Changeset{data: %Tag{}}

  """
  def change_tag(%Tag{} = tag, attrs \\ %{}) do
    Tag.changeset(tag, attrs)
  end

  #
  # Media operations
  #

  @doc """
  Returns a list of media items.

  ## Examples

      iex> list_media()
      [%Media{}, ...]

  """
  def list_media(criteria \\ []) do
    Tracer.with_span "content.list_media", %{
      criteria_count: length(criteria)
    } do
      query = from(m in Media)

      query =
        Enum.reduce(criteria, query, fn
          {:user_id, user_id}, query ->
            Tracer.add_event("filter.user_id", %{user_id: user_id})
            from q in query, where: q.user_id == ^user_id

          {:content_type, content_type}, query ->
            Tracer.add_event("filter.content_type", %{type: content_type})
            from q in query, where: q.content_type == ^content_type

          {:search, search_term}, query ->
            Tracer.add_event("filter.search", %{term: search_term})
            search_term = "%#{search_term}%"

            from q in query,
              where:
                ilike(q.filename, ^search_term) or
                  ilike(q.original_filename, ^search_term) or
                  ilike(q.alt_text, ^search_term)

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
  Gets a single media item by ID.

  Raises `Ecto.NoResultsError` if the Media does not exist.

  ## Examples

      iex> get_media!(123)
      %Media{}

      iex> get_media!(456)
      ** (Ecto.NoResultsError)

  """
  def get_media!(id) do
    Tracer.with_span "content.get_media", %{media_id: id} do
      Media
      |> Repo.get!(id)
      |> Repo.preload(:user)
    end
  rescue
    e in Ecto.NoResultsError ->
      Tracer.set_error("Media not found")
      Tracer.record_exception(e, __STACKTRACE__)
      reraise e, __STACKTRACE__
  end

  @doc """
  Creates a media item from an uploaded file.

  ## Examples

      iex> create_media_from_upload(upload, %{user_id: 1})
      {:ok, %Media{}}

      iex> create_media_from_upload(upload, %{})
      {:error, %Ecto.Changeset{}}

  """
  def create_media_from_upload(upload, attrs \\ %{}) do
    Tracer.with_span "content.create_media_from_upload" do
      user_id = Map.get(attrs, "user_id", Map.get(attrs, :user_id))

      Tracer.set_attributes(%{
        filename: upload.client_name,
        content_type: upload.content_type,
        size: upload.size,
        user_id: user_id
      })

      if Media.content_type_allowed?(upload.content_type) do
        with {:ok, path} <- MediaStorage.store_file(upload, upload.client_name) do
          media_params = %{
            filename: Path.basename(path),
            original_filename: upload.client_name,
            content_type: upload.content_type,
            path: path,
            size: upload.size,
            alt_text: Map.get(attrs, "alt_text", Map.get(attrs, :alt_text, "")),
            user_id: user_id
          }

          %Media{}
          |> Media.changeset(media_params)
          |> Repo.insert()
          |> case do
            {:ok, media} ->
              Tracer.add_event("media.created", %{id: media.id, path: media.path})

              # Log the audit event with the current user
              current_user = Map.get(attrs, :current_user)

              BeamFlow.Logger.audit(
                "media.created",
                current_user,
                %{media_id: media.id, filename: media.original_filename}
              )

              {:ok, Repo.preload(media, :user)}

            {:error, changeset} ->
              # If insertion fails, clean up the uploaded file
              MediaStorage.delete_file(path)

              Tracer.add_event("media.validation_failed", %{
                errors: inspect(changeset.errors)
              })

              Tracer.set_error("Validation failed")
              {:error, changeset}
          end
        else
          {:error, reason} ->
            {:error, reason}
        end
      else
        Tracer.add_event("media.invalid_content_type", %{type: upload.content_type})
        {:error, :content_type_not_allowed}
      end
    end
  end

  @doc """
  Updates a media item.

  ## Examples

      iex> update_media(media, %{field: new_value})
      {:ok, %Media{}}

      iex> update_media(media, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_media(%Media{} = media, attrs) do
    Tracer.with_span "content.update_media", %{media_id: media.id} do
      current_user = Map.get(attrs, :current_user)

      media
      |> Media.changeset(attrs)
      |> Repo.update()
      |> tap(fn
        {:ok, updated_media} ->
          Tracer.add_event("media.updated", %{id: updated_media.id})

          BeamFlow.Logger.audit(
            "media.updated",
            current_user,
            %{media_id: media.id, filename: media.original_filename}
          )

          {:ok, Repo.preload(updated_media, :user)}

        {:error, changeset} ->
          Tracer.add_event("media.update_failed", %{
            errors: inspect(changeset.errors)
          })

          Tracer.set_error("Update validation failed")
          {:error, changeset}
      end)
    end
  end

  @doc """
  Deletes a media item and its associated file.

  ## Examples

      iex> delete_media(media)
      {:ok, %Media{}}

      iex> delete_media(media)
      {:error, %Ecto.Changeset{}}

  """
  def delete_media(%Media{} = media, current_user \\ nil) do
    Tracer.with_span "content.delete_media", %{
      media_id: media.id,
      filename: media.original_filename
    } do
      # First, delete the file from storage
      delete_result = MediaStorage.delete_file(media.path)

      # Then, delete the database record
      case Repo.delete(media) do
        {:ok, deleted_media} ->
          Tracer.add_event("media.deleted", %{delete_result: delete_result})

          BeamFlow.Logger.audit(
            "media.deleted",
            current_user,
            %{media_id: media.id, filename: media.original_filename}
          )

          {:ok, deleted_media}

        {:error, changeset} ->
          Tracer.add_event("media.delete_failed", %{
            errors: inspect(changeset.errors)
          })

          Tracer.set_error("Delete failed")
          {:error, changeset}
      end
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking media changes.

  ## Examples

      iex> change_media(media)
      %Ecto.Changeset{data: %Media{}}

  """
  def change_media(%Media{} = media, attrs \\ %{}) do
    Media.changeset(media, attrs)
  end

  #
  # Helper functions
  #

  # Ensures a slug is unique by appending a counter if necessary for posts
  defp ensure_unique_slug(changeset) do
    case get_field(changeset, :slug) do
      nil ->
        changeset

      slug ->
        unique_slug = Slugifier.ensure_unique_slug(slug, &slug_exists?/2, changeset)

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

  # Ensures a slug is unique for categories
  defp ensure_unique_category_slug(changeset) do
    case get_field(changeset, :slug) do
      nil ->
        changeset

      slug ->
        unique_slug = Slugifier.ensure_unique_slug(slug, &category_slug_exists?/2, changeset)

        if slug != unique_slug do
          Tracer.add_event("category_slug.modified", %{
            original: slug,
            modified: unique_slug
          })

          put_change(changeset, :slug, unique_slug)
        else
          changeset
        end
    end
  end

  # Ensures a slug is unique for tags
  defp ensure_unique_tag_slug(changeset) do
    case get_field(changeset, :slug) do
      nil ->
        changeset

      slug ->
        unique_slug = Slugifier.ensure_unique_slug(slug, &tag_slug_exists?/2, changeset)

        if slug != unique_slug do
          Tracer.add_event("tag_slug.modified", %{
            original: slug,
            modified: unique_slug
          })

          put_change(changeset, :slug, unique_slug)
        else
          changeset
        end
    end
  end

  def list_posts_by_tag(%Tag{} = tag) do
    Tracer.with_span "content.list_posts_by_tag", %{tag_id: tag.id} do
      tag = Repo.preload(tag, :posts)
      tag.posts
    end
  end

  # Check if a post slug exists, excluding the current entity if it exists
  defp slug_exists?(test_slug, changeset) do
    query = from p in Post, where: p.slug == ^test_slug
    query = exclude_current_entity(query, changeset)
    Repo.exists?(query)
  end

  # Check if a category slug exists, excluding the current entity if it exists
  defp category_slug_exists?(test_slug, changeset) do
    query = from c in Category, where: c.slug == ^test_slug
    query = exclude_current_entity(query, changeset)
    Repo.exists?(query)
  end

  # Check if a tag slug exists, excluding the current entity if it exists
  defp tag_slug_exists?(test_slug, changeset) do
    query = from t in Tag, where: t.slug == ^test_slug
    query = exclude_current_entity(query, changeset)
    Repo.exists?(query)
  end

  # Exclude the current entity when checking uniqueness during updates
  defp exclude_current_entity(query, changeset) do
    case get_field(changeset, :id) do
      nil -> query
      id -> from q in query, where: q.id != ^id
    end
  end
end
