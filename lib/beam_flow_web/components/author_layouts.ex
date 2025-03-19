defmodule BeamFlowWeb.AuthorLayouts do
  @moduledoc """
  This module defines the layouts for the author area.

  It provides a standardized way to wrap author content with the
  appropriate header, navigation, and footer components.
  """
  use BeamFlowWeb, :html

  # Define helper functions for layout usage
  def current_path(conn) do
    Phoenix.Controller.current_path(conn)
  end

  # Embed the layout templates
  embed_templates "author/layouts/*"
end
