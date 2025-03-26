defmodule BeamFlow.Content.CategoryContextTest do
  use BeamFlow.DataCase, async: true
  import BeamFlowWeb.ConnCase, only: [create_test_user: 1]
  alias BeamFlow.Content
  alias BeamFlow.Content.Category

  setup do
    user = create_test_user("admin")

    {:ok, user: user}
  end

  describe "list_categories/1" do
    @tag :integration
    @tag :category_management
    test "returns all categories" do
      category = category_fixture()
      assert Content.list_categories() |> Enum.map(& &1.id) |> Enum.member?(category.id)
    end

    @tag :integration
    @tag :category_management
    test "returns categories ordered by name" do
      category1 = category_fixture(%{name: "ZCategory"})
      category2 = category_fixture(%{name: "ACategory"})

      [first, second] = Content.list_categories(order_by: [asc: :name])
      assert first.id == category2.id
      assert second.id == category1.id
    end
  end

  describe "get_category!/1" do
    @tag :integration
    @tag :category_management
    test "returns the category with given id" do
      category = category_fixture()
      assert Content.get_category!(category.id).id == category.id
    end

    @tag :integration
    @tag :category_management
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Content.get_category!(-1)
      end
    end
  end

  describe "create_category/1" do
    @tag :integration
    @tag :category_management
    test "with valid data creates a category", %{user: user} do
      valid_attrs = %{name: "Technology", description: "Tech articles", current_user: user}

      assert {:ok, %Category{} = category} = Content.create_category(valid_attrs)
      assert category.name == "Technology"
      assert category.slug == "technology"
      assert category.description == "Tech articles"
    end

    @tag :integration
    @tag :category_management
    test "with invalid data returns error changeset", %{user: user} do
      invalid_attrs = %{name: nil, current_user: user}
      assert {:error, %Ecto.Changeset{}} = Content.create_category(invalid_attrs)
    end

    @tag :integration
    @tag :category_management
    test "ensures unique slug", %{user: user} do
      # Create first category
      Content.create_category(%{name: "Technology", current_user: user})

      # Create second with same name
      {:ok, category2} = Content.create_category(%{name: "Technology", current_user: user})

      assert category2.slug =~ "technology-"
      refute category2.slug == "technology"
    end
  end

  describe "update_category/2" do
    @tag :integration
    @tag :category_management
    test "with valid data updates the category", %{user: user} do
      category = category_fixture()

      update_attrs = %{
        name: "Updated Name",
        description: "Updated description",
        current_user: user
      }

      assert {:ok, %Category{} = updated} = Content.update_category(category, update_attrs)
      assert updated.name == "Updated Name"
      assert updated.slug == "updated-name"
      assert updated.description == "Updated description"
    end

    @tag :integration
    @tag :category_management
    test "with invalid data returns error changeset", %{user: user} do
      category = category_fixture()
      invalid_attrs = %{name: nil, current_user: user}

      assert {:error, %Ecto.Changeset{}} = Content.update_category(category, invalid_attrs)
      assert category.id == Content.get_category!(category.id).id
    end
  end

  describe "delete_category/1" do
    @tag :integration
    @tag :category_management
    test "deletes the category" do
      category = category_fixture()
      assert {:ok, %Category{}} = Content.delete_category(category)
      assert_raise Ecto.NoResultsError, fn -> Content.get_category!(category.id) end
    end
  end

  defp category_fixture(attrs \\ %{}) do
    {:ok, category} =
      attrs
      |> Enum.into(%{name: "Test Category", description: "Test description"})
      |> Content.create_category()

    category
  end
end
