defmodule BeamFlowWeb.LiveAuth do
  @moduledoc """
  A module for handling role-based authorization in LiveViews.

  This module provides mount hooks that can be used in live_session to verify
  that users have the appropriate role to access admin features.

  ## Examples

  In router.ex:

      live_session :admin_only, on_mount: {BeamFlowWeb.LiveAuth, {:ensure_role, :admin}} do
        live "/admin/dashboard", AdminDashboardLive
      end

  """

  import Phoenix.LiveView
  import Phoenix.Component

  alias BeamFlow.Accounts
  alias BeamFlow.Roles

  # Default mount hook that doesn't perform any authentication
  def on_mount(:default, _params, _session, socket) do
    {:cont, socket}
  end

  # Ensures the user is authenticated, otherwise redirects to the login page
  def on_mount(:ensure_authenticated, _params, %{"user_token" => user_token} = _session, socket) do
    socket = assign_current_user(socket, user_token)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> put_flash(:error, "You must log in to access this page.")
        |> redirect(to: "/users/log_in")

      {:halt, socket}
    end
  end

  def on_mount(:ensure_authenticated, _params, _session, socket) do
    socket =
      socket
      |> put_flash(:error, "You must log in to access this page.")
      |> redirect(to: "/users/log_in")

    {:halt, socket}
  end

  # Ensures a specific role for the current user
  def on_mount(
        {:ensure_role, required_role},
        _params,
        %{"user_token" => user_token} = _session,
        socket
      ) do
    socket = assign_current_user(socket, user_token)

    if socket.assigns.current_user &&
         Roles.has_role?(socket.assigns.current_user, required_role) do
      {:cont, socket}
    else
      socket =
        socket
        |> put_flash(:error, "You don't have permission to access this page.")
        |> redirect(to: "/")

      {:halt, socket}
    end
  end

  def on_mount({:ensure_role, _role}, _params, _session, socket) do
    socket =
      socket
      |> put_flash(:error, "You must log in to access this page.")
      |> redirect(to: "/users/log_in")

    {:halt, socket}
  end

  # Ensures the user is NOT authenticated, redirects if they are
  def on_mount(
        :redirect_if_authenticated,
        _params,
        %{"user_token" => user_token} = _session,
        socket
      ) do
    socket = assign_current_user(socket, user_token)

    if socket.assigns.current_user do
      socket =
        socket
        |> redirect(to: "/")

      {:halt, socket}
    else
      {:cont, socket}
    end
  end

  def on_mount(:redirect_if_authenticated, _params, _session, socket) do
    {:cont, assign(socket, :current_user, nil)}
  end

  # Assigns the current user to the socket based on the token
  def on_mount(:assign_current_user, _params, %{"user_token" => user_token} = _session, socket) do
    socket = assign_current_user(socket, user_token)
    {:cont, socket}
  end

  def on_mount(:assign_current_user, _params, _session, socket) do
    {:cont, assign(socket, :current_user, nil)}
  end

  ## Logs the current action for auditing purposes.
  def on_mount(:audit_access, params, session, socket) do
    socket = assign_current_user(socket, session)

    if user = socket.assigns.current_user do
      path = socket.assigns.__changed__[:path] || "unknown"
      section = params["section"] || "liveview"

      Accounts.log_action("access:#{section}", user.id,
        metadata: %{
          path: path,
          params: params
        }
      )
    end

    {:cont, socket}
  end

  # Helper to assign current user to socket
  defp assign_current_user(socket, user_token) do
    assign_new(socket, :current_user, fn ->
      Accounts.get_user_by_session_token(user_token)
    end)
  end

  # Adds user roles as assigns to the socket
  def assign_user_roles(socket) do
    if user = socket.assigns[:current_user] do
      socket
      |> assign(:user_roles, Roles.get_user_roles(user))
      |> assign(:is_admin, Roles.has_role?(user, :admin))
      |> assign(:is_editor, Roles.has_role?(user, :editor))
      |> assign(:is_author, Roles.has_role?(user, :author))
    else
      socket
      |> assign(:user_roles, [])
      |> assign(:is_admin, false)
      |> assign(:is_editor, false)
      |> assign(:is_author, false)
    end
  end
end
