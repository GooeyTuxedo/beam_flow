defmodule BeamFlowWeb.Plugs.MediaAuth do
  @moduledoc """
  Plug to authorize access to media files based on user role.
  """
  import Plug.Conn
  import Phoenix.Controller

  alias BeamFlow.Roles

  def init(opts), do: opts

  def call(conn, _opts) do
    # Skip auth for public files if needed
    case public_media?(conn.path_info) do
      true -> conn
      false -> authorize_media_access(conn)
    end
  end

  # Check if media is public (optional, if you want some media to be public)
  defp public_media?(["uploads", "public" | _rest]), do: true
  defp public_media?(_path_info), do: false

  defp authorize_media_access(conn) do
    current_user = conn.assigns[:current_user]

    case current_user do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> put_view(BeamFlowWeb.ErrorHTML)
        |> render("401.html")
        |> halt()

      user ->
        # Admin can access all media
        if Roles.has_role?(user, :admin) do
          conn
        else
          # Extract media ID from path and check if user has access
          # This would require parsing the path and loading the media
          # For simplicity, we'll allow all authenticated users for now
          conn
        end
    end
  end
end
