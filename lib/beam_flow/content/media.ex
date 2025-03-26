defmodule BeamFlow.Content.Media do
  @moduledoc """
  Schema and changeset functions for media files in BeamFlow CMS.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "media" do
    field :filename, :string
    field :original_filename, :string
    field :content_type, :string
    field :path, :string
    field :size, :integer
    field :alt_text, :string
    field :metadata, :map, default: %{}

    belongs_to :user, BeamFlow.Accounts.User

    timestamps()
  end

  # List of allowed MIME types
  @allowed_content_types [
    "image/jpeg",
    "image/png",
    "image/gif",
    "image/svg+xml",
    "application/pdf"
  ]

  # Maximum file size in bytes (10MB)
  @max_file_size 10 * 1024 * 1024

  @doc """
  Creates a changeset for media items.
  """
  def changeset(media, attrs) do
    media
    |> cast(attrs, [
      :filename,
      :original_filename,
      :content_type,
      :path,
      :size,
      :alt_text,
      :metadata,
      :user_id
    ])
    |> validate_required([
      :filename,
      :original_filename,
      :content_type,
      :path,
      :size,
      :user_id
    ])
    |> validate_inclusion(:content_type, @allowed_content_types)
    |> validate_number(:size, less_than_or_equal_to: @max_file_size)
    |> unique_constraint(:path)
  end

  @doc """
  Returns whether a content type is allowed.
  """
  def content_type_allowed?(content_type) do
    content_type in @allowed_content_types
  end

  @doc """
  Returns the maximum allowed file size in bytes.
  """
  def max_file_size, do: @max_file_size
end
