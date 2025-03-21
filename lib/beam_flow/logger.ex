defmodule BeamFlow.Logger do
  @moduledoc """
  Centralized logging module for BeamFlow application.

  This module provides standardized logging functions with proper context
  metadata and helps maintain consistent log formatting across the application.

  It also provides hooks for log processing and monitoring.
  """

  alias BeamFlow.Accounts.AuditLog
  require Logger

  @doc """
  Sets up hookable logging for LoggerJSON backend.

  Called during logger initialization.
  """
  def setup_hookable do
    # Can be used to connect to log monitoring systems
    # or set up hooks for log processing
    :ok
  end

  @doc """
  Logs a message at debug level with context metadata.
  """
  def debug(message, metadata \\ []) do
    Logger.debug(message, metadata: sanitize_metadata(metadata))
  end

  @doc """
  Logs a message at info level with context metadata.
  """
  def info(message, metadata \\ []) do
    Logger.info(message, metadata: sanitize_metadata(metadata))
  end

  @doc """
  Logs a message at warning level with context metadata.
  """
  def warn(message, metadata \\ []) do
    Logger.warning(message, metadata: sanitize_metadata(metadata))
  end

  @doc """
  Logs a message at error level with context metadata.
  """
  def error(message, metadata \\ []) do
    Logger.error(message, metadata: sanitize_metadata(metadata))
  end

  @doc """
  Logs an audit event with user info and action details.
  """
  def audit(action, user_or_id, details \\ %{}, metadata \\ []) do
    {user_id, role} = extract_user_info(user_or_id)

    audit_metadata =
      metadata
      |> Keyword.put(:user_id, user_id)
      |> Keyword.put(:role, role)
      |> Keyword.put(:action, action)
      |> Keyword.put(:audit, true)

    # For audit logs, include full details in message
    message = "AUDIT: [#{action}] #{inspect(details)}"

    # Log the audit event
    Logger.info(message, metadata: sanitize_metadata(audit_metadata))

    # If we have a user model and details are a map, record to database
    if is_map(details) and not is_nil(user_id) do
      task =
        Task.async(fn ->
          record_audit_log(user_id, action, details)
        end)

      # We don't wait for the result but ensure errors are logged
      Task.start(fn ->
        try do
          Task.await(task)
        rescue
          e -> Logger.error("Failed to record audit log: #{inspect(e)}")
        end
      end)
    end

    :ok
  end

  @doc """
  Logs a user authentication event.
  """
  def auth_event(event, user_or_id, metadata \\ []) do
    {user_id, role} = extract_user_info(user_or_id)

    auth_metadata =
      metadata
      |> Keyword.put(:user_id, user_id)
      |> Keyword.put(:role, role)
      |> Keyword.put(:auth_event, event)

    Logger.info("AUTH: [#{event}] User #{user_id}", metadata: sanitize_metadata(auth_metadata))
  end

  @doc """
  Sets or updates the process metadata for the current process.
  Useful for controllers and LiveView processes to add request context.
  """
  def put_process_metadata(metadata) do
    # Update the process dictionary with the new metadata
    current = Logger.metadata()
    Logger.metadata(Keyword.merge(current, sanitize_metadata(metadata)))
  end

  @doc """
  Sets user context in the process metadata.
  """
  def put_user_context(user_or_id) do
    {user_id, role} = extract_user_info(user_or_id)

    Logger.metadata(
      user_id: user_id,
      role: role
    )
  end

  @doc """
  Clears user context from the process metadata.
  """
  def clear_user_context do
    metadata = Logger.metadata()
    Logger.metadata(Keyword.drop(metadata, [:user_id, :role]))
  end

  # Private functions

  # Record audit log to database using the existing AuditLog module
  defp record_audit_log(user_id, action, details) do
    # Get IP from process metadata if available
    ip_address = Logger.metadata()[:ip]

    # Format resource information if available
    {resource_type, resource_id} = extract_resource_info(details)

    # Use the existing log_action function
    AuditLog.log_action(
      BeamFlow.Repo,
      to_string(action),
      user_id,
      ip_address: ip_address,
      metadata: details,
      resource_type: resource_type,
      resource_id: resource_id
    )
  end

  # Extract resource information from details if possible
  defp extract_resource_info(details) when is_map(details) do
    cond do
      Map.has_key?(details, :post_id) ->
        {"post", to_string(details.post_id)}

      Map.has_key?(details, :user_id) ->
        {"user", to_string(details.user_id)}

      Map.has_key?(details, :comment_id) ->
        {"comment", to_string(details.comment_id)}

      true ->
        {nil, nil}
    end
  end

  defp extract_resource_info(_other), do: {nil, nil}

  # Extract user ID and role from user or user_id
  defp extract_user_info(user_or_id) do
    cond do
      is_nil(user_or_id) ->
        {nil, nil}

      is_map(user_or_id) and Map.has_key?(user_or_id, :id) ->
        {user_or_id.id, Map.get(user_or_id, :role)}

      is_integer(user_or_id) or is_binary(user_or_id) ->
        {user_or_id, nil}

      true ->
        {nil, nil}
    end
  end

  # Sanitize metadata to ensure only valid data is included
  defp sanitize_metadata(metadata) when is_list(metadata) do
    metadata
    |> Enum.filter(fn {_k, v} -> not is_function(v) end)
    |> Enum.map(fn {k, v} -> {k, sanitize_value(v)} end)
  end

  defp sanitize_metadata(_other), do: []

  # Sanitize specific values that shouldn't be logged
  defp sanitize_value(value) when is_binary(value) do
    cond do
      String.contains?(to_string(value), ["password", "token", "secret", "key"]) ->
        "[REDACTED]"

      String.length(to_string(value)) > 1000 ->
        String.slice(to_string(value), 0, 1000) <> "... [truncated]"

      true ->
        value
    end
  end

  defp sanitize_value(value) when is_map(value) do
    if map_size(value) > 20 do
      value
      |> Map.take(Enum.take(Map.keys(value), 20))
      |> Map.put(:truncated, true)
    else
      value
    end
  end

  defp sanitize_value(value), do: value
end
