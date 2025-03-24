defmodule BeamFlowWeb.API.AuthController do
  use BeamFlowWeb, :controller

  alias BeamFlow.Accounts
  alias BeamFlow.Accounts.RateLimiter
  alias BeamFlow.Logger

  def create(conn, %{"email" => email, "password" => password}) do
    case Accounts.get_user_by_email_and_password(email, password) do
      %Accounts.User{} = user ->
        # Log successful authentication
        Logger.audit("api.token.create", user, %{ip_address: format_ip(conn.remote_ip)})

        # Generate API token
        token = Accounts.generate_api_token(user)

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

  def delete(conn, _params) do
    # If we got here, authentication worked and current_user is available
    user = conn.assigns.current_user
    token = get_token_from_header(conn)

    # Use the token to revoke it
    case Accounts.revoke_api_token(token) do
      :ok ->
        # Log the event
        Logger.audit("api.token.revoke", user, %{})

        conn
        |> send_resp(:no_content, "")

      :error ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: %{status: 400, message: "Failed to revoke token"}})
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
