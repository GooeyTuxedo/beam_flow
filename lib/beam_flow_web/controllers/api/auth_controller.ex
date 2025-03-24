defmodule BeamFlowWeb.API.AuthController do
  use BeamFlowWeb, :controller

  alias BeamFlow.Accounts
  alias BeamFlow.Accounts.RateLimiter
  alias BeamFlow.Logger
  alias BeamFlow.Tracer

  require BeamFlow.Tracer
  require OpenTelemetry.Tracer

  def create(conn, %{"email" => email, "password" => password}) do
    Tracer.with_span "api.auth.token_create", %{
      client_ip: format_ip(conn.remote_ip),
      user_agent: get_user_agent(conn),
      email: email
    } do
      case Accounts.get_user_by_email_and_password(email, password) do
        %Accounts.User{} = user ->
          # Log successful authentication
          Logger.audit("api.token.create", user, %{ip_address: format_ip(conn.remote_ip)})

          Tracer.add_event("auth.success", %{
            user_id: user.id,
            role: user.role
          })

          # Generate API token
          token = Accounts.generate_api_token(user)

          Tracer.add_event("token.generated", %{
            token_length: String.length(token)
          })

          conn
          |> put_status(:created)
          |> json(%{
            token: token,
            token_type: "Bearer",
            # 30 days in seconds
            expires_in: 2_592_000
          })

        nil ->
          # Rate limit failed login attempts
          RateLimiter.record_attempt("api:login:#{format_ip(conn.remote_ip)}")

          Tracer.add_event("auth.failed", %{})
          Tracer.set_error("Invalid credentials")

          # Log failed attempt
          Logger.warn("Failed API authentication attempt",
            email: email,
            ip_address: format_ip(conn.remote_ip)
          )

          conn
          |> put_status(:unauthorized)
          |> json(%{error: %{status: 401, message: "Invalid email or password"}})
      end
    end
  end

  def delete(conn, _params) do
    Tracer.with_span "api.auth.token_revoke", %{
      user_id: conn.assigns.current_user.id,
      client_ip: format_ip(conn.remote_ip),
      user_agent: get_user_agent(conn)
    } do
      # If we got here, authentication worked and current_user is available
      user = conn.assigns.current_user
      token = get_token_from_header(conn)

      Tracer.add_event("token.revoking", %{
        user_id: user.id,
        role: user.role
      })

      # Use the token to revoke it
      case Accounts.revoke_api_token(token) do
        :ok ->
          # Log the event
          Logger.audit("api.token.revoke", user, %{})

          Tracer.add_event("token.revoked", %{})

          conn
          |> send_resp(:no_content, "")

        :error ->
          Tracer.add_event("token.revoke_failed", %{})
          Tracer.set_error("Failed to revoke token")

          conn
          |> put_status(:bad_request)
          |> json(%{error: %{status: 400, message: "Failed to revoke token"}})
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

  defp get_user_agent(conn) do
    case get_req_header(conn, "user-agent") do
      [user_agent] -> user_agent
      _other -> "unknown"
    end
  end
end
