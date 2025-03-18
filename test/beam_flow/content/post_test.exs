defmodule BeamFlow.Content.PostTest do
  use BeamFlow.DataCase, async: true

  alias BeamFlow.Content.Post

  @valid_attrs %{
    title: "Test Post",
    content: "This is a test post content.",
    excerpt: "Test excerpt",
    user_id: 1
  }

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Post.changeset(%Post{}, %{})
      assert %{title: ["can't be blank"], user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates status values" do
      changeset = Post.changeset(%Post{}, Map.put(@valid_attrs, :status, "invalid"))
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "scheduled posts require published_at" do
      changeset = Post.changeset(%Post{}, Map.put(@valid_attrs, :status, "scheduled"))
      assert %{published_at: ["must be set for scheduled posts"]} = errors_on(changeset)
    end

    test "sets published_at for published posts if not provided" do
      changeset = Post.changeset(%Post{}, Map.put(@valid_attrs, :status, "published"))
      assert %{published_at: _published_at} = changeset.changes
    end

    test "validates slug format" do
      changeset = Post.changeset(%Post{}, Map.put(@valid_attrs, :slug, "Invalid Slug!"))

      assert %{slug: ["must contain only lowercase letters, numbers, and hyphens"]} =
               errors_on(changeset)
    end

    test "validates slug length" do
      changeset = Post.changeset(%Post{}, Map.put(@valid_attrs, :slug, "ab"))
      assert %{slug: ["should be at least 3 character(s)"]} = errors_on(changeset)

      long_slug = String.duplicate("a", 101)
      changeset = Post.changeset(%Post{}, Map.put(@valid_attrs, :slug, long_slug))
      assert %{slug: ["should be at most 100 character(s)"]} = errors_on(changeset)
    end
  end

  describe "create_changeset/2" do
    test "generates slug from title if not provided" do
      changeset = Post.create_changeset(%Post{}, @valid_attrs)
      assert changeset.changes.slug == "test-post"
    end

    test "uses provided slug if available" do
      attrs = Map.merge(@valid_attrs, %{slug: "custom-slug"})
      changeset = Post.create_changeset(%Post{}, attrs)
      assert changeset.changes.slug == "custom-slug"
    end

    test "handles special characters in title for slug" do
      attrs = Map.merge(@valid_attrs, %{title: "Test & Special: Characters!"})
      changeset = Post.create_changeset(%Post{}, attrs)
      assert changeset.changes.slug == "test-special-characters"
    end
  end

  describe "slugify/1" do
    test "converts spaces to hyphens" do
      assert Post.slugify("Hello World") == "hello-world"
    end

    test "removes special characters" do
      assert Post.slugify("Hello! @World#") == "hello-world"
    end

    test "converts uppercase to lowercase" do
      assert Post.slugify("HELLO WORLD") == "hello-world"
    end

    test "handles multiple spaces" do
      assert Post.slugify("Hello   World") == "hello-world"
    end

    test "handles leading and trailing spaces" do
      assert Post.slugify("  Hello World  ") == "hello-world"
    end

    test "handles multiple hyphens" do
      assert Post.slugify("Hello--World") == "hello-world"
    end
  end
end
