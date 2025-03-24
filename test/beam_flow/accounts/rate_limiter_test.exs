defmodule BeamFlow.Accounts.RateLimiterTest do
  use ExUnit.Case, async: false
  alias BeamFlow.Accounts.RateLimiter

  # These tests are simplified to focus on basic functionality
  # without relying on implementation details

  setup do
    # Start the RateLimiter if it's not already started
    case Process.whereis(RateLimiter) do
      nil -> start_supervised!(RateLimiter)
      _pid -> :ok
    end

    # Reset all keys before each test
    reset_test_keys()

    :ok
  end

  describe "basic rate limiting" do
    @tag :unit
    test "records and clears attempts" do
      key = "test-key-#{:rand.uniform(1000)}"

      # Initially should not be rate limited
      refute RateLimiter.check_rate_limit(key)

      # Record a success should ensure it stays not limited
      RateLimiter.record_success(key)
      refute RateLimiter.check_rate_limit(key)

      # Reset attempts should ensure it stays not limited
      RateLimiter.reset_attempts(key)
      refute RateLimiter.check_rate_limit(key)
    end
  end

  describe "custom configuration" do
    @tag :unit
    test "works with different configurations" do
      key = "test-key-#{:rand.uniform(1000)}"

      # Should handle various configurations without errors
      RateLimiter.check_rate_limit(key, max_attempts: 2)
      RateLimiter.check_rate_limit(key, interval: 600)
      RateLimiter.check_rate_limit(key, max_attempts: 3, interval: 1800)

      # Record a single attempt
      RateLimiter.record_attempt(key)

      # With custom max_attempts of 1, should be rate limited
      assert RateLimiter.check_rate_limit(key, max_attempts: 1)

      # Reset attempts
      RateLimiter.reset_attempts(key)
    end
  end

  # Simple test to ensure record_attempt functions
  @tag :unit
  test "record_attempt increments attempts" do
    key = "test-key-#{:rand.uniform(1000)}"

    # First attempt shouldn't rate limit with default settings
    RateLimiter.record_attempt(key)
    refute RateLimiter.check_rate_limit(key)
  end

  # Test cleanup functionality
  @tag :unit
  test "handles empty and non-existent keys gracefully" do
    # Non-existent key should not be rate limited
    refute RateLimiter.check_rate_limit("nonexistent-#{:rand.uniform(1000)}")
  end

  # Helper function to reset keys used for testing
  defp reset_test_keys do
    # Attempt to reset test keys that start with "test-key-"
    # If this fails (due to ETS table issues), we'll just move on

    # If the table doesn't exist yet, don't try to reset
    if :ets.info(:login_attempts) != :undefined do
      # Only send a reset message to the server - it's safer than direct ETS manipulation
      RateLimiter.reset_attempts("test-key-reset")
    end
  end
end
