defmodule BeamFlowWeb.AdminLayouts do
  @moduledoc """
  This module defines the layouts for the admin area.

  It provides a standardized way to wrap admin content with the
  appropriate header, navigation, and footer components.
  """
  use BeamFlowWeb, :html
  import BeamFlowWeb.DashboardComponents

  # Define helper functions for layout usage
  def current_path(conn) do
    Phoenix.Controller.current_path(conn)
  end

  # Embed the layout templates
  embed_templates "admin/layouts/*"
end
