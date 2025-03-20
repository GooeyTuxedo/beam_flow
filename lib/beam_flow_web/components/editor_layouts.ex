defmodule BeamFlowWeb.EditorLayouts do
  @moduledoc """
  This module defines the layouts for the editor area.

  It provides a standardized way to wrap editor content with the
  appropriate header, navigation, and footer components.
  """
  use BeamFlowWeb, :html
  import BeamFlowWeb.DashboardComponents

  # Define helper functions for layout usage
  def current_path(conn) do
    Phoenix.Controller.current_path(conn)
  end

  # Embed the layout templates
  embed_templates "editor/layouts/*"
end
