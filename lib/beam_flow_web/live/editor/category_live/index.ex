defmodule BeamFlowWeb.Editor.CategoryLive.Index do
  use BeamFlowWeb, :live_view

  alias BeamFlowWeb.CategoryLive.Index

  # Delegate to the shared implementation
  def mount(params, session, socket) do
    Index.mount(params, session, socket)
  end

  def handle_params(params, url, socket) do
    Index.handle_params(params, url, socket)
  end

  def handle_event(event, params, socket) do
    Index.handle_event(event, params, socket)
  end

  def render(assigns) do
    Index.render(assigns)
  end
end
