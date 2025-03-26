defmodule BeamFlow.Content.CategoryTest do
  use BeamFlow.DataCase, async: true
  alias BeamFlow.Content.Category

  @valid_attrs %{name: "Technology", description: "Tech-related content"}
  @invalid_attrs %{name: nil, slug: nil}

  describe "changeset/2" do
    @tag :unit
    @tag :validation
    test "with valid attributes" do
      changeset = Category.changeset(%Category{}, @valid_attrs)
      assert changeset.valid?
    end

    @tag :unit
    @tag :validation
    test "with invalid attributes" do
      changeset = Category.changeset(%Category{}, @invalid_attrs)
      refute changeset.valid?
    end

    @tag :unit
    @tag :validation
    test "generates slug from name" do
      changeset = Category.changeset(%Category{}, @valid_attrs)
      assert get_change(changeset, :slug) == "technology"
    end

    @tag :unit
    @tag :validation
    test "validates slug format" do
      changeset = Category.changeset(%Category{}, %{name: "Valid", slug: "in valid"})

      assert %{slug: ["must contain only lowercase letters, numbers, and hyphens"]} =
               errors_on(changeset)
    end

    @tag :unit
    @tag :validation
    test "keeps existing slug if provided" do
      changeset = Category.changeset(%Category{}, %{name: "Technology", slug: "custom-slug"})
      assert get_change(changeset, :slug) == "custom-slug"
    end
  end
end
