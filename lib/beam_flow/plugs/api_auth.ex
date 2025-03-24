defmodule BeamFlowWeb.Plugs.APIAuth do
  @moduledoc """
  Plug for authenticating API requests using bearer tokens.
  """

  import Plug.Conn

  alias BeamFlow.Accounts
  alias BeamFlow.Logger
  alias BeamFlow.Tracer

  require BeamFlow.Tracer
  require OpenTelemetry.Tracer

  def init(opts), do: opts

  def call(conn, _opts) do
    Tracer.with_span "api.auth.authenticate", %{
      path: conn.request_path,
      method: conn.method,
      client_ip: format_ip(conn.remote_ip)
    } do
      case get_token_from_header(conn) do
        nil ->
          Tracer.add_event("auth.no_token", %{})
          Tracer.set_error("Authentication required")

          conn
          |> put_resp_content_type("application/json")
          |> send_resp(
            401,
            Jason.encode!(%{error: %{status: 401, message: "Authentication required"}})
          )
          |> halt()

        token ->
          case Accounts.get_user_by_api_token(token) do
            nil ->
              Logger.warn("Invalid API token used", ip: format_ip(conn.remote_ip))

              Tracer.add_event("auth.invalid_token", %{})
              Tracer.set_error("Invalid token")

              conn
              |> put_resp_content_type("application/json")
              |> send_resp(401, Jason.encode!(%{error: %{status: 401, message: "Invalid token"}}))
              |> halt()

            user ->
              # Add trace attributes with proper require
              Tracer.set_attributes(%{
                "user.id" => user.id,
                "user.role" => user.role
              })

              Tracer.add_event("auth.successful", %{
                user_id: user.id,
                role: user.role
              })

              Logger.put_user_context(user)

              conn
              |> assign(:current_user, user)
              |> assign(:api_authenticated, true)
          end
      end
    end
  end

  defp get_token_from_header(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> token
      _other -> nil
    end
  end

  defp format_ip(ip) when is_tuple(ip), do: to_string(:inet.ntoa(ip))
  defp format_ip(_ip), do: "unknown"
end
