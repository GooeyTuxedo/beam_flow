defmodule BeamFlowWeb.Plugs.APIAuth do
  @moduledoc """
  Plug for authenticating API requests using bearer tokens.
  """

  import Plug.Conn

  alias BeamFlow.Accounts
  alias BeamFlow.Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_token_from_header(conn) do
      nil ->
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

            conn
            |> put_resp_content_type("application/json")
            |> send_resp(401, Jason.encode!(%{error: %{status: 401, message: "Invalid token"}}))
            |> halt()

          user ->
            # Add trace attributes with proper require
            require BeamFlow.Tracer

            BeamFlow.Tracer.set_attributes(%{
              "user.id" => user.id,
              "user.role" => user.role
            })

            Logger.put_user_context(user)

            conn
            |> assign(:current_user, user)
            |> assign(:api_authenticated, true)
        end
    end
  end

  defp get_token_from_header(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> token
      _other -> nil
    end
  end

  # Fix pipe chain
  defp format_ip(ip) when is_tuple(ip), do: to_string(:inet.ntoa(ip))
  defp format_ip(_ip), do: "unknown"
end
