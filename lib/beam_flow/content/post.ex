defmodule BeamFlow.Content.Post do
  @moduledoc """
  Schema and business logic for blog posts in the BeamFlow CMS.

  Posts are the core content type of the CMS, containing markdown content,
  metadata, and publishing state management.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @status_values ~w(draft published scheduled)

  schema "posts" do
    field :title, :string
    field :slug, :string
    field :content, :string
    field :excerpt, :string
    field :status, :string, default: "draft"
    field :published_at, :utc_datetime

    belongs_to :user, BeamFlow.Accounts.User

    timestamps()
  end

  @doc """
  Creates a changeset for a post.
  """
  def changeset(post, attrs) do
    post
    |> cast(attrs, [:title, :slug, :content, :excerpt, :status, :published_at, :user_id])
    |> validate_required([:title, :user_id])
    |> validate_inclusion(:status, @status_values)
    |> validate_published_status()
    |> validate_slug()
    |> unique_constraint(:slug)
  end

  @doc """
  Creates a changeset for a new post with auto-generated slug.
  """
  def create_changeset(post, attrs) do
    post
    |> changeset(attrs)
    |> generate_slug_if_not_provided()
  end

  defp validate_published_status(changeset) do
    status = get_field(changeset, :status)
    published_at = get_field(changeset, :published_at)

    cond do
      status == "published" and is_nil(published_at) ->
        put_change(changeset, :published_at, DateTime.utc_now() |> DateTime.truncate(:second))

      status == "scheduled" and is_nil(published_at) ->
        add_error(changeset, :published_at, "must be set for scheduled posts")

      true ->
        changeset
    end
  end

  defp generate_slug_if_not_provided(changeset) do
    case get_field(changeset, :slug) do
      nil ->
        case get_field(changeset, :title) do
          nil -> changeset
          title -> put_change(changeset, :slug, slugify(title))
        end

      _changeset ->
        changeset
    end
  end

  defp validate_slug(changeset) do
    changeset
    |> validate_format(:slug, ~r/^[a-z0-9\-]+$/,
      message: "must contain only lowercase letters, numbers, and hyphens"
    )
    |> validate_length(:slug, min: 3, max: 100)
  end

  @doc """
  Generates a URL-friendly slug from a string.
  """
  def slugify(title) do
    title
    |> String.downcase()
    # Remove non-alphanumeric/space/hyphen chars
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    # Replace spaces with hyphens
    |> String.replace(~r/\s+/, "-")
    # Replace multiple hyphens with single
    |> String.replace(~r/-{2,}/, "-")
    # Trim hyphens from start and end
    |> String.trim("-")
  end
end
