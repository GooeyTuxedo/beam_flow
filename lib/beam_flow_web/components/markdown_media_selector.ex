defmodule BeamFlowWeb.Components.MarkdownMediaSelector do
  @moduledoc """
  LiveComponent for selecting media to insert into the markdown editor.
  """
  use BeamFlowWeb, :live_component

  alias BeamFlowWeb.Components.MediaLibraryComponent
  alias BeamFlowWeb.Components.MediaUploaderComponent

  @impl true
  def update(%{target_component: _target} = assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:tab, fn -> "library" end)

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:tab, fn -> "library" end)
      |> assign_new(:target_component, fn -> nil end)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="mb-4 border-b border-gray-200">
        <nav class="flex -mb-px space-x-8" aria-label="Tabs">
          <button
            phx-click="change-tab"
            phx-value-tab="library"
            phx-target={@myself}
            class={[
              "py-4 px-1 text-center border-b-2 font-medium text-sm",
              if(@tab == "library",
                do: "border-indigo-500 text-indigo-600",
                else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
              )
            ]}
          >
            Media Library
          </button>
          <button
            phx-click="change-tab"
            phx-value-tab="upload"
            phx-target={@myself}
            class={[
              "py-4 px-1 text-center border-b-2 font-medium text-sm",
              if(@tab == "upload",
                do: "border-indigo-500 text-indigo-600",
                else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
              )
            ]}
          >
            Upload New
          </button>
        </nav>
      </div>

      <%= if @tab == "library" do %>
        <.live_component
          module={MediaLibraryComponent}
          id="markdown-media-library"
          current_user={@current_user}
          target_component={@myself}
          filter={%{}}
        />
      <% else %>
        <.live_component
          module={MediaUploaderComponent}
          id="markdown-media-uploader"
          current_user={@current_user}
          target_component={@myself}
        />
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("change-tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab, tab)}
  end

  @impl true
  def handle_event("media-selected", %{"id" => media_id}, socket) do
    # Forward the media selection to the parent component
    target = socket.assigns.target_component

    if target do
      send_update(target, id: target.id, event: "media-selected", id: media_id)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("media-uploaded", %{"id" => media_id}, socket) do
    socket = assign(socket, :tab, "library")

    # Forward the media upload event to the parent component
    target = socket.assigns.target_component

    if target do
      send_update(target, id: target.id, event: "media-selected", id: media_id)
    end

    {:noreply, socket}
  end
end
