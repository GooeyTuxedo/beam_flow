defmodule BeamFlow.Plugs.TraceContext do
  @moduledoc """
  Plug to add OpenTelemetry trace context to requests.

  This plug enriches spans with user and request information to provide
  better context for distributed tracing.
  """

  @behaviour Plug

  require OpenTelemetry.Tracer, as: OtelTracer
  alias BeamFlow.Tracer

  def init(opts), do: opts

  def call(conn, _opts) do
    # Add user context if available
    if user = conn.assigns[:current_user] do
      Tracer.set_attributes(%{
        "user.id" => user.id,
        "user.email" => user.email,
        "user.role" => user.role
      })
    end

    # Add request context
    Tracer.set_attributes(%{
      "http.method" => conn.method,
      "http.path" => conn.request_path,
      "http.client_ip" => format_ip(conn.remote_ip),
      "http.user_agent" => get_header(conn, "user-agent"),
      "http.request_id" => List.first(Plug.Conn.get_resp_header(conn, "x-request-id"))
    })

    # Update logger metadata with trace information
    update_logger_metadata()

    # Register a before_send callback to record response information
    Plug.Conn.register_before_send(conn, &before_send/1)
  end

  # Called before the response is sent
  defp before_send(conn) do
    # Add response attributes to the current span
    Tracer.set_attributes(%{
      "http.status_code" => conn.status,
      "http.response_content_type" => get_content_type(conn)
    })

    # Mark errors based on status code
    if conn.status >= 500 do
      Tracer.set_error("HTTP #{conn.status}")
    end

    conn
  end

  # Add trace context to logger metadata
  defp update_logger_metadata do
    trace_id = Tracer.current_trace_id()
    span_id = Tracer.current_span_id()

    if trace_id && span_id do
      require Logger

      Logger.metadata(
        trace_id: trace_id,
        span_id: span_id
      )
    end
  end

  # Get content type from response
  defp get_content_type(conn) do
    conn
    |> Plug.Conn.get_resp_header("content-type")
    |> List.first()
    |> case do
      nil ->
        "unknown"

      content_type ->
        List.first(String.split(content_type, ";"))
    end
  end

  # Format IP address for logging
  defp format_ip(ip) when is_tuple(ip) do
    ip
    |> :inet.ntoa()
    |> to_string()
  end

  defp format_ip(_ip), do: "unknown"

  # Get a request header safely
  defp get_header(conn, header) do
    case Plug.Conn.get_req_header(conn, header) do
      [value | _rest] -> value
      _unknown -> "unknown"
    end
  end
end
