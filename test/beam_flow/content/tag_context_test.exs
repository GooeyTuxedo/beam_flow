defmodule BeamFlow.Content.TagContextTest do
  use BeamFlow.DataCase, async: true
  import BeamFlowWeb.ConnCase, only: [create_test_user: 1]
  alias BeamFlow.Content
  alias BeamFlow.Content.Tag

  setup do
    user = create_test_user("admin")

    {:ok, user: user}
  end

  describe "list_tags/1" do
    @tag :integration
    @tag :tag_management
    test "returns all tags" do
      tag = tag_fixture()
      assert Content.list_tags() |> Enum.map(& &1.id) |> Enum.member?(tag.id)
    end

    @tag :integration
    @tag :tag_management
    test "returns tags ordered by name" do
      tag1 = tag_fixture(%{name: "ZTag"})
      tag2 = tag_fixture(%{name: "ATag"})

      [first, second] = Content.list_tags(order_by: [asc: :name])
      assert first.id == tag2.id
      assert second.id == tag1.id
    end
  end

  describe "get_tag!/1" do
    @tag :integration
    @tag :tag_management
    test "returns the tag with given id" do
      tag = tag_fixture()
      assert Content.get_tag!(tag.id).id == tag.id
    end

    @tag :integration
    @tag :tag_management
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Content.get_tag!(-1)
      end
    end
  end

  describe "create_tag/1" do
    @tag :integration
    @tag :tag_management
    test "with valid data creates a tag", %{user: user} do
      valid_attrs = %{name: "Elixir", current_user: user}

      assert {:ok, %Tag{} = tag} = Content.create_tag(valid_attrs)
      assert tag.name == "Elixir"
      assert tag.slug == "elixir"
    end

    @tag :integration
    @tag :tag_management
    test "with invalid data returns error changeset", %{user: user} do
      invalid_attrs = %{name: nil, current_user: user}
      assert {:error, %Ecto.Changeset{}} = Content.create_tag(invalid_attrs)
    end

    @tag :integration
    @tag :tag_management
    test "ensures unique slug", %{user: user} do
      # Create first tag
      Content.create_tag(%{name: "Elixir", current_user: user})

      # Create second with same name
      {:ok, tag2} = Content.create_tag(%{name: "Elixir", current_user: user})

      assert tag2.slug =~ "elixir-"
      refute tag2.slug == "elixir"
    end
  end

  describe "update_tag/2" do
    @tag :integration
    @tag :tag_management
    test "with valid data updates the tag", %{user: user} do
      tag = tag_fixture()
      update_attrs = %{name: "Updated", current_user: user}

      assert {:ok, %Tag{} = updated} = Content.update_tag(tag, update_attrs)
      assert updated.name == "Updated"
      assert updated.slug == "updated"
    end

    @tag :integration
    @tag :tag_management
    test "with invalid data returns error changeset", %{user: user} do
      tag = tag_fixture()
      invalid_attrs = %{name: nil, current_user: user}

      assert {:error, %Ecto.Changeset{}} = Content.update_tag(tag, invalid_attrs)
      assert tag.id == Content.get_tag!(tag.id).id
    end
  end

  describe "delete_tag/1" do
    @tag :integration
    @tag :tag_management
    test "deletes the tag" do
      tag = tag_fixture()
      assert {:ok, %Tag{}} = Content.delete_tag(tag)
      assert_raise Ecto.NoResultsError, fn -> Content.get_tag!(tag.id) end
    end
  end

  defp tag_fixture(attrs \\ %{}) do
    {:ok, tag} =
      attrs
      |> Enum.into(%{name: "Elixir"})
      |> Content.create_tag()

    tag
  end
end
