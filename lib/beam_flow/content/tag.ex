defmodule BeamFlow.Content.Tag do
  @moduledoc """
  Schema for blog post tags.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias BeamFlow.Content.Post
  alias BeamFlow.Utils.Slugifier

  schema "tags" do
    field :name, :string
    field :slug, :string

    many_to_many :posts, Post, join_through: "post_tags", on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name, :slug])
    |> validate_required([:name])
    |> generate_slug_if_needed()
    |> validate_slug()
    |> unique_constraint(:slug)
  end

  defp generate_slug_if_needed(%Ecto.Changeset{valid?: true} = changeset) do
    # Only generate a slug if one wasn't explicitly provided
    case get_change(changeset, :slug) do
      nil ->
        # No slug provided, generate from name
        case get_change(changeset, :name) do
          nil -> changeset
          name -> put_change(changeset, :slug, Slugifier.slugify(name))
        end

      _slug ->
        # Slug was explicitly provided, keep it
        changeset
    end
  end

  defp generate_slug_if_needed(changeset), do: changeset

  defp validate_slug(changeset) do
    # Only validate slug if it's being changed or if it's present
    if get_change(changeset, :slug) || get_field(changeset, :slug) do
      changeset
      |> validate_format(:slug, ~r/^[a-z0-9\-]+$/,
        message: "must contain only lowercase letters, numbers, and hyphens"
      )
      |> validate_length(:slug, min: 3, max: 100)
    else
      changeset
    end
  end
end
