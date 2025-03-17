defmodule BeamFlow.Accounts.ListUsersTest do
  use BeamFlow.DataCase, async: true

  import BeamFlow.AccountsFixtures

  alias BeamFlow.Accounts

  describe "list_users/0" do
    test "returns all users" do
      user1 = user_fixture()
      user2 = user_fixture()
      user3 = user_fixture()

      users = Accounts.list_users()

      # Check that our test users are in the result
      assert Enum.any?(users, fn u -> u.id == user1.id end)
      assert Enum.any?(users, fn u -> u.id == user2.id end)
      assert Enum.any?(users, fn u -> u.id == user3.id end)
    end

    test "returns users with all expected fields" do
      user =
        user_fixture(%{
          name: "Test User",
          email: "test@example.com",
          role: :admin
        })

      [found_user] = Accounts.list_users() |> Enum.filter(fn u -> u.id == user.id end)

      assert found_user.name == "Test User"
      assert found_user.email == "test@example.com"
      assert found_user.role == :admin
    end
  end

  describe "list_users_by_role/1" do
    test "returns only users with the specified role" do
      admin = user_fixture(%{role: :admin})
      editor = user_fixture(%{role: :editor})
      author = user_fixture(%{role: :author})
      subscriber = user_fixture(%{role: :subscriber})

      admin_users = Accounts.list_users_by_role(:admin)
      editor_users = Accounts.list_users_by_role(:editor)
      author_users = Accounts.list_users_by_role(:author)
      subscriber_users = Accounts.list_users_by_role(:subscriber)

      # Check that users are in the correct role lists
      assert Enum.any?(admin_users, fn u -> u.id == admin.id end)
      assert Enum.any?(editor_users, fn u -> u.id == editor.id end)
      assert Enum.any?(author_users, fn u -> u.id == author.id end)
      assert Enum.any?(subscriber_users, fn u -> u.id == subscriber.id end)

      # Check that users are not in incorrect role lists
      refute Enum.any?(admin_users, fn u -> u.id == editor.id end)
      refute Enum.any?(editor_users, fn u -> u.id == author.id end)
      refute Enum.any?(author_users, fn u -> u.id == subscriber.id end)
      refute Enum.any?(admin_users, fn u -> u.id == subscriber.id end)
    end

    test "returns an empty list for role with no users" do
      # We'll use a valid role but ensure no users have it
      # First, make sure all users have roles other than :author
      user_fixture(%{role: :admin})
      user_fixture(%{role: :editor})
      user_fixture(%{role: :subscriber})

      # Now check for authors, which should return empty list
      author_users = Accounts.list_users_by_role(:author)

      assert author_users == []
    end
  end
end
