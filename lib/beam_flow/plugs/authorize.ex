defmodule BeamFlowWeb.Plugs.Authorize do
  @moduledoc """
  A plug for authorization in controllers and LiveViews.

  ## Examples

  In a controller:

      plug BeamFlowWeb.Plugs.Authorize, :admin when action in [:delete, :update]

  In a LiveView:

      on_mount {BeamFlowWeb.Plugs.Authorize, :editor}
  """

  import Plug.Conn

  alias BeamFlow.Accounts.AuditLog
  alias BeamFlow.Accounts.Auth

  # For use in controllers
  def init(role), do: role

  def call(conn, role) do
    user = conn.assigns.current_user

    if Auth.has_role?(user, role) do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(:error, "Unauthorized access")
      |> Phoenix.Controller.redirect(to: "/")
      |> halt()
    end
  end

  # For use in LiveViews
  def on_mount(role, _params, session, socket) do
    %{"user_token" => user_token} = session

    user = BeamFlow.Accounts.get_user_by_session_token(user_token)

    if Auth.has_role?(user, role) do
      {:cont, assign(socket, :current_user, user)}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "Unauthorized access")
        |> Phoenix.LiveView.redirect(to: "/")

      {:halt, socket}
    end
  end

  @doc """
  Authorizes an action in a controller and logs the attempt.

  ## Examples

      def update(conn, %{"id" => id}) do
        post = Content.get_post!(id)

        with :ok <- Authorize.action(conn, :update, {:post, post}) do
          # Authorized, continue with the action
        end
      end
  """
  def action(conn, action, resource) do
    user = conn.assigns.current_user
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()

    result = Auth.authorize(user, action, resource)

    # Log the authorization attempt
    {resource_type, resource_data} = resource
    resource_id = extract_resource_id(resource_data)

    AuditLog.log_action(BeamFlow.Repo, "authorize:#{action}:#{resource_type}", user.id,
      ip_address: ip,
      resource_type: to_string(resource_type),
      resource_id: resource_id,
      metadata: %{
        result: result == :ok,
        path: conn.request_path
      }
    )

    result
  end

  # For use in LiveViews
  def authorize(socket, action, resource) do
    user = socket.assigns.current_user

    case Auth.authorize(user, action, resource) do
      :ok ->
        {:ok, socket}

      {:error, :unauthorized} ->
        {:error, Phoenix.LiveView.put_flash(socket, :error, "Unauthorized action")}
    end
  end

  # Helper to extract an ID from various resource types
  defp extract_resource_id(resource) when is_map(resource) do
    cond do
      Map.has_key?(resource, :id) -> to_string(resource.id)
      Map.has_key?(resource, "id") -> resource["id"]
      true -> nil
    end
  end

  defp extract_resource_id(resource) when is_binary(resource), do: resource
  defp extract_resource_id(resource), do: inspect(resource)
end
