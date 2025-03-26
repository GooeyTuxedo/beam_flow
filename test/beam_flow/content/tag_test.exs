defmodule BeamFlow.Content.TagTest do
  use BeamFlow.DataCase, async: true
  alias BeamFlow.Content.Tag

  @valid_attrs %{name: "Elixir"}
  @invalid_attrs %{name: nil}

  describe "changeset/2" do
    @tag :unit
    @tag :validation
    test "with valid attributes" do
      changeset = Tag.changeset(%Tag{}, @valid_attrs)
      assert changeset.valid?
    end

    @tag :unit
    @tag :validation
    test "with invalid attributes" do
      changeset = Tag.changeset(%Tag{}, @invalid_attrs)
      refute changeset.valid?
    end

    @tag :unit
    @tag :validation
    test "generates slug from name" do
      changeset = Tag.changeset(%Tag{}, @valid_attrs)
      assert get_change(changeset, :slug) == "elixir"
    end

    @tag :unit
    @tag :validation
    test "validates slug format" do
      changeset = Tag.changeset(%Tag{}, %{name: "Valid", slug: "in valid"})

      assert %{slug: ["must contain only lowercase letters, numbers, and hyphens"]} =
               errors_on(changeset)
    end

    @tag :unit
    @tag :validation
    test "keeps existing slug if provided" do
      changeset = Tag.changeset(%Tag{}, %{name: "Elixir", slug: "custom-slug"})
      assert get_change(changeset, :slug) == "custom-slug"
    end
  end
end
