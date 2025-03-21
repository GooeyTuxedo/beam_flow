defmodule BeamFlow.Plugs.RequestLogger do
  @moduledoc """
  Plug to handle request logging with proper context.

  This plug captures request information and adds it to the logger metadata,
  ensuring all logs within the request context include relevant information.
  """

  @behaviour Plug

  alias BeamFlow.Logger
  alias Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    start_time = System.monotonic_time()

    # Set basic request metadata
    request_metadata = [
      request_id: List.first(Conn.get_resp_header(conn, "x-request-id")),
      ip: format_ip(conn.remote_ip),
      method: conn.method,
      path: conn.request_path
    ]

    # Add metadata to logger
    Logger.put_process_metadata(request_metadata)

    # If user is authenticated, add user context
    if user = conn.assigns[:current_user] do
      Logger.put_user_context(user)
    end

    # Register before_send callback to log response
    Conn.register_before_send(conn, fn conn ->
      duration =
        (System.monotonic_time() - start_time) |> System.convert_time_unit(:native, :millisecond)

      # Get final status code
      status = conn.status
      level = choose_log_level(status)

      # Update metadata with response info
      Logger.put_process_metadata(
        status: status,
        duration: duration
      )

      # Log the request completion
      log_request(level, conn, duration)

      conn
    end)
  end

  # Choose log level based on status code
  defp choose_log_level(status) when status >= 500, do: :error
  defp choose_log_level(status) when status >= 400, do: :warning
  defp choose_log_level(_status), do: :info

  # Format IP address for logging
  defp format_ip(ip) when is_tuple(ip) do
    ip
    |> :inet.ntoa()
    |> to_string()
  end

  defp format_ip(_unknown), do: "unknown"

  # Log the request with appropriate level
  defp log_request(level, conn, duration) do
    message = "#{conn.method} #{conn.request_path} - #{conn.status} (#{duration}ms)"

    case level do
      :error -> Logger.error(message)
      :warning -> Logger.warn(message)
      _other -> Logger.info(message)
    end
  end
end
