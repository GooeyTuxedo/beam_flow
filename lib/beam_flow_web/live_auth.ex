defmodule BeamFlowWeb.LiveAuth do
  @moduledoc """
  A module for handling role-based authorization in LiveViews.

  This module provides mount hooks that can be used in live_session to verify
  that users have the appropriate role to access admin features.

  ## Examples

  In router.ex:

      live_session :admin_only, on_mount: {BeamFlowWeb.LiveAuth, :ensure_admin} do
        live "/admin/dashboard", AdminDashboardLive
      end

  """

  import Phoenix.LiveView
  import Phoenix.Component

  alias BeamFlow.Accounts

  ## Ensures the current user has admin role.
  def on_mount(:ensure_admin, _params, session, socket) do
    authorize_role(socket, session, :admin)
  end

  ## Ensures the current user has editor role (or higher).
  def on_mount(:ensure_editor, _params, session, socket) do
    authorize_role(socket, session, :editor)
  end

  ## Ensures the current user has author role (or higher).
  def on_mount(:ensure_author, _params, session, socket) do
    authorize_role(socket, session, :author)
  end

  ## Ensures the current user has at least the specified role.
  def on_mount({:ensure_role, role}, _params, session, socket) do
    authorize_role(socket, session, role)
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

  # Private helper functions

  defp authorize_role(socket, %{"user_token" => user_token}, required_role) do
    socket = assign_current_user(socket, user_token)
    user = socket.assigns.current_user

    cond do
      is_nil(user) ->
        socket =
          socket
          |> put_flash(:error, "You must log in to access this page.")
          |> redirect(to: "/users/log_in")

        {:halt, socket}

      Accounts.has_role?(user, required_role) ->
        {:cont, socket}

      true ->
        socket =
          socket
          |> put_flash(:error, "You don't have permission to access this page.")
          |> redirect(to: "/")

        {:halt, socket}
    end
  end

  defp authorize_role(socket, _session, _role) do
    socket =
      socket
      |> put_flash(:error, "You must log in to access this page.")
      |> redirect(to: "/users/log_in")

    {:halt, socket}
  end

  defp assign_current_user(socket, user_token) when is_binary(user_token) do
    assign_new(socket, :current_user, fn ->
      Accounts.get_user_by_session_token(user_token)
    end)
  end

  defp assign_current_user(socket, %{"user_token" => user_token}) do
    assign_current_user(socket, user_token)
  end

  defp assign_current_user(socket, _user_token) do
    assign(socket, :current_user, nil)
  end
end
