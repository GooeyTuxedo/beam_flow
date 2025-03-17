defmodule BeamFlowWeb.LiveAuth do
  @moduledoc """
  A module for handling authentication in LiveViews.
  """

  import Phoenix.LiveView
  import Phoenix.Component

  alias BeamFlow.Accounts

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
         Accounts.has_role?(socket.assigns.current_user, required_role) do
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

  # Helper to assign current user to socket
  defp assign_current_user(socket, user_token) do
    assign_new(socket, :current_user, fn ->
      Accounts.get_user_by_session_token(user_token)
    end)
  end
end
