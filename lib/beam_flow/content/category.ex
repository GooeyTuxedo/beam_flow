defmodule BeamFlow.Content.Category do
  @moduledoc """
  Schema for blog post categories.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias BeamFlow.Content.Post
  alias BeamFlow.Utils.Slugifier

  schema "categories" do
    field :name, :string
    field :slug, :string
    field :description, :string

    many_to_many :posts, Post, join_through: "post_categories", on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :slug, :description])
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
