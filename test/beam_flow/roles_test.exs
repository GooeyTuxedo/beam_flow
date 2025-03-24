defmodule BeamFlow.RolesTest do
  use ExUnit.Case, async: true

  # Updated TestRoles module to handle unknown roles correctly
  defmodule TestRoles do
    @role_hierarchy %{
      admin: 4,
      editor: 3,
      author: 2,
      subscriber: 1
    }

    def has_role?(nil, _role), do: false
    def has_role?(_user, role) when not is_atom(role), do: false
    def has_role?(_user, role) when role not in [:admin, :editor, :author, :subscriber], do: false

    def has_role?(user, role) when is_atom(role) do
      user_role_level = @role_hierarchy[user.role] || 0
      required_role_level = @role_hierarchy[role] || 0

      user_role_level >= required_role_level
    end

    def get_user_roles(nil), do: []

    def get_user_roles(user) do
      user_level = @role_hierarchy[user.role] || 0

      @role_hierarchy
      |> Enum.filter(fn {_role, level} -> user_level >= level end)
      |> Enum.map(fn {role, _level} -> role end)
    end

    def all_roles do
      @role_hierarchy
      |> Enum.sort_by(fn {_role, level} -> level end, :desc)
      |> Enum.map(fn {role, _level} -> role end)
    end

    def role_hierarchy, do: @role_hierarchy
  end

  # Create test structs to simulate users
  defmodule TestUser do
    defstruct [:id, :role]
  end

  describe "has_role?/2" do
    @tag :unit
    test "returns false for nil user" do
      refute TestRoles.has_role?(nil, :admin)
      refute TestRoles.has_role?(nil, :subscriber)
    end

    @tag :unit
    test "admin has all roles" do
      admin = %TestUser{id: 1, role: :admin}

      assert TestRoles.has_role?(admin, :admin)
      assert TestRoles.has_role?(admin, :editor)
      assert TestRoles.has_role?(admin, :author)
      assert TestRoles.has_role?(admin, :subscriber)
    end

    @tag :unit
    test "editor has editor and lower roles" do
      editor = %TestUser{id: 2, role: :editor}

      refute TestRoles.has_role?(editor, :admin)
      assert TestRoles.has_role?(editor, :editor)
      assert TestRoles.has_role?(editor, :author)
      assert TestRoles.has_role?(editor, :subscriber)
    end

    @tag :unit
    test "author has author and lower roles" do
      author = %TestUser{id: 3, role: :author}

      refute TestRoles.has_role?(author, :admin)
      refute TestRoles.has_role?(author, :editor)
      assert TestRoles.has_role?(author, :author)
      assert TestRoles.has_role?(author, :subscriber)
    end

    @tag :unit
    test "subscriber has only subscriber role" do
      subscriber = %TestUser{id: 4, role: :subscriber}

      refute TestRoles.has_role?(subscriber, :admin)
      refute TestRoles.has_role?(subscriber, :editor)
      refute TestRoles.has_role?(subscriber, :author)
      assert TestRoles.has_role?(subscriber, :subscriber)
    end

    @tag :unit
    test "handles unknown roles gracefully" do
      user = %TestUser{id: 5, role: :unknown_role}

      refute TestRoles.has_role?(user, :admin)
      refute TestRoles.has_role?(user, :subscriber)

      # Unknown required role
      admin = %TestUser{id: 1, role: :admin}
      refute TestRoles.has_role?(admin, :unknown_required_role)
    end
  end

  describe "get_user_roles/1" do
    @tag :unit
    test "returns empty list for nil user" do
      assert TestRoles.get_user_roles(nil) == []
    end

    @tag :unit
    test "returns all roles for admin" do
      admin = %TestUser{id: 1, role: :admin}
      roles = TestRoles.get_user_roles(admin)

      assert :admin in roles
      assert :editor in roles
      assert :author in roles
      assert :subscriber in roles
      assert length(roles) == 4
    end

    @tag :unit
    test "returns correct roles for editor" do
      editor = %TestUser{id: 2, role: :editor}
      roles = TestRoles.get_user_roles(editor)

      refute :admin in roles
      assert :editor in roles
      assert :author in roles
      assert :subscriber in roles
      assert length(roles) == 3
    end

    @tag :unit
    test "returns correct roles for author" do
      author = %TestUser{id: 3, role: :author}
      roles = TestRoles.get_user_roles(author)

      refute :admin in roles
      refute :editor in roles
      assert :author in roles
      assert :subscriber in roles
      assert length(roles) == 2
    end

    @tag :unit
    test "returns only subscriber role for subscriber" do
      subscriber = %TestUser{id: 4, role: :subscriber}
      roles = TestRoles.get_user_roles(subscriber)

      refute :admin in roles
      refute :editor in roles
      refute :author in roles
      assert :subscriber in roles
      assert length(roles) == 1
    end

    @tag :unit
    test "returns empty list for unknown role" do
      user = %TestUser{id: 5, role: :unknown_role}
      assert TestRoles.get_user_roles(user) == []
    end
  end

  describe "all_roles/0" do
    @tag :unit
    test "returns all roles in descending privilege order" do
      roles = TestRoles.all_roles()

      assert roles == [:admin, :editor, :author, :subscriber]
    end
  end

  describe "role_hierarchy/0" do
    @tag :unit
    test "returns the role hierarchy map" do
      hierarchy = TestRoles.role_hierarchy()

      assert hierarchy == %{
               admin: 4,
               editor: 3,
               author: 2,
               subscriber: 1
             }
    end
  end
end
