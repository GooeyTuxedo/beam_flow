defmodule BeamFlow.Content.MediaTest do
  use BeamFlow.DataCase, async: true

  import BeamFlowWeb.ConnCase, only: [create_test_user: 1]

  alias BeamFlow.Content.Media

  @valid_attrs %{
    filename: "test.jpg",
    original_filename: "original_test.jpg",
    content_type: "image/jpeg",
    path: "/uploads/2025/03/26/abc123.jpg",
    size: 1024,
    alt_text: "Test image",
    user_id: nil
  }

  describe "changeset/2" do
    setup do
      user = create_test_user("author")
      {:ok, user: user}
    end

    test "validates required fields", %{user: _user} do
      changeset = Media.changeset(%Media{}, %{})

      assert %{
               filename: ["can't be blank"],
               original_filename: ["can't be blank"],
               content_type: ["can't be blank"],
               path: ["can't be blank"],
               size: ["can't be blank"],
               user_id: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "valid with all required fields", %{user: user} do
      attrs = Map.put(@valid_attrs, :user_id, user.id)
      changeset = Media.changeset(%Media{}, attrs)
      assert changeset.valid?
    end

    test "validates content type", %{user: user} do
      attrs = Map.put(@valid_attrs, :user_id, user.id)

      # Test valid content type
      changeset = Media.changeset(%Media{}, attrs)
      assert changeset.valid?

      # Test invalid content type
      invalid_attrs = Map.put(attrs, :content_type, "application/exe")
      changeset = Media.changeset(%Media{}, invalid_attrs)
      assert %{content_type: ["is invalid"]} = errors_on(changeset)
    end

    test "validates file size", %{user: user} do
      attrs = Map.put(@valid_attrs, :user_id, user.id)

      # Test valid size
      changeset = Media.changeset(%Media{}, attrs)
      assert changeset.valid?

      # Test too large
      max_size = Media.max_file_size()
      too_large_attrs = Map.put(attrs, :size, max_size + 1)
      changeset = Media.changeset(%Media{}, too_large_attrs)
      errors = errors_on(changeset)
      assert errors[:size]
      assert hd(errors[:size]) =~ "must be less than or equal to"
    end
  end

  describe "content_type_allowed?/1" do
    test "returns true for allowed content types" do
      assert Media.content_type_allowed?("image/jpeg")
      assert Media.content_type_allowed?("image/png")
      assert Media.content_type_allowed?("image/gif")
      assert Media.content_type_allowed?("image/svg+xml")
      assert Media.content_type_allowed?("application/pdf")
    end

    test "returns false for disallowed content types" do
      refute Media.content_type_allowed?("application/exe")
      refute Media.content_type_allowed?("text/plain")
      refute Media.content_type_allowed?("application/octet-stream")
    end
  end
end
