defmodule BeamFlow.Utils.Slugifier do
  @moduledoc """
  Utility module for generating and managing URL-friendly slugs.
  """

  @doc """
  Generates a URL-friendly slug from a string.
  Handles Unicode characters by transliterating to ASCII approximations.
  """
  def slugify(string) do
    string
    |> String.downcase()
    |> transliterate()
    |> remove_special_chars()
    |> replace_spaces_with_hyphens()
    |> remove_duplicate_hyphens()
    |> String.trim("-")
  end

  @doc """
  Ensures a slug is unique by appending a counter if necessary.
  Takes a function that checks if the slug exists and the changeset.
  """
  def ensure_unique_slug(slug, exists_fn, changeset, counter \\ 2)

  # When a changeset is provided
  def ensure_unique_slug(slug, exists_fn, changeset, counter) when is_map(changeset) do
    if exists_fn.(slug, changeset) do
      new_slug = "#{slug}-#{counter}"
      ensure_unique_slug(new_slug, exists_fn, changeset, counter + 1)
    else
      slug
    end
  end

  # Legacy support for single-argument exists functions
  def ensure_unique_slug(slug, exists_fn, nil, counter) do
    if exists_fn.(slug) do
      new_slug = "#{slug}-#{counter}"
      ensure_unique_slug(new_slug, exists_fn, nil, counter + 1)
    else
      slug
    end
  end

  # Transliterates Unicode characters to their ASCII equivalents
  defp transliterate(string) do
    # This is a simplified version. In a real implementation,
    # we would use a more comprehensive transliteration table.
    string
    |> String.normalize(:nfd)
    |> String.replace(~r/[^A-z\s]/u, "")
  end

  defp remove_special_chars(string) do
    String.replace(string, ~r/[^a-z0-9\s-]/u, "")
  end

  defp replace_spaces_with_hyphens(string) do
    String.replace(string, ~r/\s+/, "-")
  end

  defp remove_duplicate_hyphens(string) do
    String.replace(string, ~r/-{2,}/, "-")
  end
end
