defmodule BeamFlow.Accounts.RateLimiter do
  @moduledoc """
  Provides rate limiting functionality for login attempts.

  Uses ETS to store counts of login attempts per IP address or email.
  """

  use GenServer

  # Client API

  @doc """
  Starts the RateLimiter GenServer.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Checks if an IP address or email has exceeded the maximum number of login attempts.

  ## Options

    * `:max_attempts` - The maximum number of attempts allowed. Defaults to 5.
    * `:interval` - The time interval in seconds to check. Defaults to 5 minutes (300 seconds).
  """
  def check_rate_limit(key, opts \\ []) do
    max_attempts = Keyword.get(opts, :max_attempts, 5)
    interval = Keyword.get(opts, :interval, 300)

    GenServer.call(__MODULE__, {:check_rate_limit, key, max_attempts, interval})
  end

  @doc """
  Records a login attempt for an IP address or email.
  """
  def record_attempt(key) do
    GenServer.cast(__MODULE__, {:record_attempt, key})
  end

  @doc """
  Records a successful login for an IP address or email, which clears the rate limit.
  """
  def record_success(key) do
    GenServer.cast(__MODULE__, {:record_success, key})
  end

  @doc """
  Manually resets the rate limit for a key.
  """
  def reset_attempts(key) do
    GenServer.cast(__MODULE__, {:reset_attempts, key})
  end

  # Server Callbacks

  @impl true
  def init(:ok) do
    # Create ETS table for storing login attempts
    table = :ets.new(:login_attempts, [:set, :protected, :named_table])

    # Start a periodic task to clean up old entries
    schedule_cleanup()

    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:check_rate_limit, key, max_attempts, interval}, _from, state) do
    case :ets.lookup(:login_attempts, key) do
      [{^key, attempts, timestamps}] ->
        # Filter timestamps to only include those within the interval
        now = System.system_time(:second)
        valid_timestamps = Enum.filter(timestamps, &(&1 > now - interval))

        # Check if the number of valid attempts exceeds the maximum
        is_limited = length(valid_timestamps) >= max_attempts

        {:reply, is_limited, state}

      [] ->
        {:reply, false, state}
    end
  end

  @impl true
  def handle_cast({:record_attempt, key}, state) do
    now = System.system_time(:second)

    :ets.insert(
      :login_attempts,
      case :ets.lookup(:login_attempts, key) do
        [{^key, attempts, timestamps}] ->
          {key, attempts + 1, [now | timestamps]}

        [] ->
          {key, 1, [now]}
      end
    )

    {:noreply, state}
  end

  @impl true
  def handle_cast({:record_success, key}, state) do
    :ets.delete(:login_attempts, key)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:reset_attempts, key}, state) do
    :ets.delete(:login_attempts, key)
    {:noreply, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = System.system_time(:second)

    # Keep entries that have any valid attempts in the last hour
    :ets.foldl(
      fn {key, _attempts, timestamps}, _acc ->
        valid_timestamps = Enum.filter(timestamps, &(&1 > now - 3600))

        if Enum.empty?(valid_timestamps) do
          :ets.delete(:login_attempts, key)
        end
      end,
      nil,
      :login_attempts
    )

    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    # Run cleanup every hour
    Process.send_after(self(), :cleanup, 3600 * 1000)
  end
end
