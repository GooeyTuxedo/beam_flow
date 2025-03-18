defmodule BeamFlow.Accounts.AuditLogTest do
  use BeamFlow.DataCase

  alias BeamFlow.Accounts
  alias BeamFlow.Accounts.AuditLog
  import BeamFlow.AccountsFixtures

  setup do
    # Create test users
    users = %{
      admin: user_fixture(%{role: :admin}),
      editor: user_fixture(%{role: :editor}),
      author: user_fixture(%{role: :author}),
      subscriber: user_fixture(%{role: :subscriber})
    }

    %{users: users}
  end

  describe "basic audit logging" do
    test "logs different action types", %{users: %{admin: user}} do
      # Test login action
      {:ok, login_log} = AuditLog.log_action(Repo, "login", user.id, ip_address: "127.0.0.1")
      assert login_log.action == "login"
      assert login_log.user_id == user.id
      assert login_log.ip_address == "127.0.0.1"

      # Test resource action
      {:ok, update_log} =
        AuditLog.log_action(
          Repo,
          "update",
          user.id,
          resource_type: "post",
          resource_id: "123"
        )

      assert update_log.action == "update"
      assert update_log.resource_type == "post"
      assert update_log.resource_id == "123"

      # Test with extra metadata
      {:ok, meta_log} =
        AuditLog.log_action(
          Repo,
          "publish",
          user.id,
          metadata: %{title: "Test Post", status: "published"}
        )

      assert meta_log.action == "publish"
      # Check metadata values (as strings due to deep_stringify_keys)
      assert meta_log.metadata["title"] == "Test Post"
      assert meta_log.metadata["status"] == "published"
    end

    test "allows logging without a user id" do
      # System actions don't always have a user
      {:ok, log} =
        AuditLog.log_action(Repo, "system_backup", nil,
          metadata: %{size: "1.2GB", duration: "15m"}
        )

      assert log.action == "system_backup"
      assert log.user_id == nil
      assert log.metadata["size"] == "1.2GB"
    end

    test "validates required fields" do
      # Action is the only required field
      {:error, changeset} = AuditLog.log_action(Repo, nil, nil)
      assert "can't be blank" in errors_on(changeset).action

      # All other fields are optional
      {:ok, log} = AuditLog.log_action(Repo, "minimal_action", nil)
      assert log.action == "minimal_action"
    end
  end

  describe "query functions" do
    test "list_user_logs returns logs for a specific user", %{
      users: %{admin: user1, editor: user2}
    } do
      # Add logs for both users
      {:ok, _log} =
        AuditLog.log_action(Repo, "action1", user1.id, resource_type: "post", resource_id: "1")

      {:ok, _log} =
        AuditLog.log_action(Repo, "action2", user1.id, resource_type: "post", resource_id: "1")

      {:ok, _log} =
        AuditLog.log_action(Repo, "action3", user2.id, resource_type: "post", resource_id: "2")

      # Test user logs query
      user_logs = Repo.all(AuditLog.list_user_logs(AuditLog, user1.id))
      assert length(user_logs) == 2
      assert Enum.all?(user_logs, &(&1.user_id == user1.id))

      # Test with a different user
      user2_logs = Repo.all(AuditLog.list_user_logs(AuditLog, user2.id))
      assert length(user2_logs) == 1
      assert hd(user2_logs).user_id == user2.id

      # Test with non-existent user
      nonexistent_logs = Repo.all(AuditLog.list_user_logs(AuditLog, 9999))
      assert Enum.empty?(nonexistent_logs)
    end

    test "list_resource_logs returns logs for a specific resource", %{
      users: %{admin: user1, editor: user2}
    } do
      # Add logs for different resources
      {:ok, _log} =
        AuditLog.log_action(Repo, "view", user1.id, resource_type: "post", resource_id: "1")

      {:ok, _log} =
        AuditLog.log_action(Repo, "edit", user1.id, resource_type: "post", resource_id: "1")

      {:ok, _log} =
        AuditLog.log_action(Repo, "view", user2.id, resource_type: "post", resource_id: "2")

      {:ok, _log} =
        AuditLog.log_action(Repo, "delete", user1.id, resource_type: "comment", resource_id: "5")

      # Test resource logs query for a specific post
      post1_logs = Repo.all(AuditLog.list_resource_logs(AuditLog, "post", "1"))
      assert length(post1_logs) == 2
      assert Enum.all?(post1_logs, &(&1.resource_id == "1" and &1.resource_type == "post"))

      # Test resource logs query for a different post
      post2_logs = Repo.all(AuditLog.list_resource_logs(AuditLog, "post", "2"))
      assert length(post2_logs) == 1
      assert hd(post2_logs).resource_id == "2"

      # Test resource logs query for a comment
      comment_logs = Repo.all(AuditLog.list_resource_logs(AuditLog, "comment", "5"))
      assert length(comment_logs) == 1
      assert hd(comment_logs).resource_type == "comment"

      # Test with non-existent resource
      nonexistent_logs = Repo.all(AuditLog.list_resource_logs(AuditLog, "post", "999"))
      assert Enum.empty?(nonexistent_logs)
    end

    test "list_recent_logs returns recent logs with correct ordering", %{users: %{admin: user}} do
      # Insert logs with explicit timestamps to test ordering
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      # Create logs with timestamps in reverse order (newest first)
      for i <- 1..5 do
        # Each log i minutes older
        timestamp = NaiveDateTime.add(now, -i * 60, :second)

        # Create log changeset
        log =
          %AuditLog{}
          |> AuditLog.changeset(%{
            action: "action#{i}",
            user_id: user.id,
            resource_type: "test",
            resource_id: "#{i}"
          })
          |> Ecto.Changeset.put_change(:inserted_at, timestamp)

        # Insert directly
        Repo.insert!(log)
      end

      # Test recent logs query with default limit
      recent_logs = Repo.all(AuditLog.list_recent_logs(AuditLog))
      assert length(recent_logs) == 5

      # Check the order (should be newest first)
      ordered_actions = Enum.map(recent_logs, & &1.action)
      assert ordered_actions == ["action1", "action2", "action3", "action4", "action5"]

      # Test with custom limit
      limited_logs = Repo.all(AuditLog.list_recent_logs(AuditLog, 3))
      assert length(limited_logs) == 3
      assert Enum.map(limited_logs, & &1.action) == ["action1", "action2", "action3"]
    end
  end

  describe "integration with Accounts context" do
    test "Accounts.log_action creates audit log entries", %{users: %{subscriber: user}} do
      {:ok, log} = Accounts.log_action("login", user.id, ip_address: "192.168.1.1")

      assert log.action == "login"
      assert log.user_id == user.id
      assert log.ip_address == "192.168.1.1"

      # Check it can be queried back
      user_logs = Accounts.list_user_logs(user.id)
      assert length(user_logs) == 1
      assert hd(user_logs).action == "login"
    end

    test "Accounts.list_user_logs retrieves user logs", %{users: %{author: user}} do
      # Create several logs
      Accounts.log_action("login", user.id)
      Accounts.log_action("view_dashboard", user.id)
      Accounts.log_action("create_post", user.id, resource_type: "post", resource_id: "1")

      # Retrieve logs
      logs = Accounts.list_user_logs(user.id)

      assert length(logs) == 3

      # Check limit works
      limited_logs = Accounts.list_user_logs(user.id, 2)
      assert length(limited_logs) == 2
    end

    test "Accounts.list_resource_logs retrieves resource logs", %{
      users: %{editor: user1, author: user2}
    } do
      # Create logs for the same resource from different users
      Accounts.log_action("view", user1.id, resource_type: "post", resource_id: "42")
      Accounts.log_action("edit", user1.id, resource_type: "post", resource_id: "42")
      Accounts.log_action("view", user2.id, resource_type: "post", resource_id: "42")

      # Create log for a different resource
      Accounts.log_action("delete", user1.id, resource_type: "post", resource_id: "43")

      # Retrieve logs for resource 42
      logs = Accounts.list_resource_logs("post", "42")

      assert length(logs) == 3
      assert Enum.all?(logs, &(&1.resource_id == "42"))

      # Verify logs show different users
      logs = Enum.map(logs, & &1.user_id)
      user_ids = logs |> Enum.uniq() |> Enum.sort()
      assert user_ids == [user1.id, user2.id] |> Enum.sort()
    end

    test "Accounts.list_recent_logs retrieves recent logs", %{users: users} do
      # Create logs from different users
      Accounts.log_action("action1", users.admin.id)
      Accounts.log_action("action2", users.editor.id)
      Accounts.log_action("action3", users.author.id)

      # Retrieve recent logs
      logs = Accounts.list_recent_logs()

      # At least our 3 logs
      assert length(logs) >= 3

      # Check for our actions (not checking order here since there might be other logs)
      actions = Enum.map(logs, & &1.action)
      assert "action1" in actions
      assert "action2" in actions
      assert "action3" in actions
    end
  end

  describe "edge cases" do
    test "handles basic metadata values", %{} do
      user = user_fixture()

      # Simple metadata map
      metadata = %{
        "key1" => "value1",
        "key2" => 123,
        "key3" => true
      }

      # Should handle basic metadata without issues
      {:ok, log} = AuditLog.log_action(Repo, "metadata_test", user.id, metadata: metadata)

      # Verify we can retrieve it
      retrieved_log = Repo.get!(AuditLog, log.id)

      # Check values without assuming string/atom keys
      assert get_in(retrieved_log.metadata, ["key1"]) == "value1"
      assert get_in(retrieved_log.metadata, ["key2"]) == 123
      assert get_in(retrieved_log.metadata, ["key3"]) == true
    end

    test "normalizes IP addresses properly", %{users: %{editor: user}} do
      # Test handling of various IP formats
      {:ok, log1} = AuditLog.log_action(Repo, "ip_test_1", user.id, ip_address: "192.168.1.1")

      {:ok, log2} =
        AuditLog.log_action(Repo, "ip_test_2", user.id,
          ip_address: "2001:db8:3333:4444:5555:6666:7777:8888"
        )

      {:ok, log3} =
        AuditLog.log_action(Repo, "ip_test_3", user.id, ip_address: "invalid-ip-format")

      {:ok, log4} = AuditLog.log_action(Repo, "ip_test_4", user.id, ip_address: nil)

      # All should be stored without errors
      assert log1.ip_address == "192.168.1.1"
      assert log2.ip_address == "2001:db8:3333:4444:5555:6666:7777:8888"
      assert log3.ip_address == "invalid-ip-format"
      assert log4.ip_address == nil
    end
  end
end
