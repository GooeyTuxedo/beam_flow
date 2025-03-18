defmodule BeamFlow.AccountsProfileTest do
  use BeamFlow.DataCase, async: true

  import BeamFlow.AccountsFixtures

  alias BeamFlow.Accounts
  alias BeamFlow.Accounts.User

  describe "user profile management" do
    test "update profile information" do
      user = user_fixture()

      # Update changeset for profile
      attrs = %{
        name: "Updated Name",
        bio: "This is my new bio information"
      }

      changeset = User.profile_changeset(user, attrs)
      {:ok, updated_user} = Repo.update(changeset)

      assert updated_user.name == "Updated Name"
      assert updated_user.bio == "This is my new bio information"
      # Email should remain unchanged
      assert updated_user.email == user.email
    end

    test "validates profile information" do
      user = user_fixture()

      # Test with invalid data
      attrs = %{
        # Empty name should be invalid
        name: "",
        # Bio too long
        bio: String.duplicate("x", 1001)
      }

      changeset = User.profile_changeset(user, attrs)
      assert changeset.valid? == false
      assert "can't be blank" in errors_on(changeset).name

      assert Enum.any?(
               errors_on(changeset).bio,
               &String.contains?(&1, "should be at most 1000 character")
             )
    end
  end

  describe "user role management" do
    test "update user role" do
      user = user_fixture(%{role: :subscriber})

      # Create role changeset
      changeset = User.role_changeset(user, %{role: :author})
      {:ok, updated_user} = Repo.update(changeset)

      assert updated_user.role == :author
    end

    test "validates role values" do
      user = user_fixture()

      # Test with invalid role
      changeset = User.role_changeset(user, %{role: :invalid_role})
      assert changeset.valid? == false
      assert "is invalid" in errors_on(changeset).role
    end

    test "role changes affect permissions immediately" do
      user = user_fixture(%{role: :subscriber})

      # Initial permissions
      assert BeamFlow.Roles.has_role?(user, :subscriber)
      refute BeamFlow.Roles.has_role?(user, :author)

      # Update role
      {:ok, updated_user} =
        user
        |> User.role_changeset(%{role: :author})
        |> Repo.update()

      # Verify new permissions
      assert BeamFlow.Roles.has_role?(updated_user, :subscriber)
      assert BeamFlow.Roles.has_role?(updated_user, :author)
      refute BeamFlow.Roles.has_role?(updated_user, :editor)
    end
  end

  describe "list_users functions" do
    test "list_users returns all users" do
      # Create several users with different roles
      admin = user_fixture(%{role: :admin})
      editor = user_fixture(%{role: :editor})
      author = user_fixture(%{role: :author})
      subscriber = user_fixture(%{role: :subscriber})

      users = Accounts.list_users()

      # Check if all our users are in the results
      user_ids = Enum.map(users, & &1.id)
      assert admin.id in user_ids
      assert editor.id in user_ids
      assert author.id in user_ids
      assert subscriber.id in user_ids
    end

    test "list_users_by_role filters users correctly" do
      # Create several users with different roles
      user_fixture(%{role: :admin, email: "admin1@example.com"})
      user_fixture(%{role: :admin, email: "admin2@example.com"})
      user_fixture(%{role: :editor})
      user_fixture(%{role: :author})
      user_fixture(%{role: :subscriber})

      # Get admin users
      admin_users = Accounts.list_users_by_role(:admin)

      # Should only return admin users
      assert length(admin_users) == 2
      assert Enum.all?(admin_users, &(&1.role == :admin))

      # Get author users
      author_users = Accounts.list_users_by_role(:author)

      # Should only return author users
      assert length(author_users) == 1
      assert Enum.all?(author_users, &(&1.role == :author))
    end
  end
end
