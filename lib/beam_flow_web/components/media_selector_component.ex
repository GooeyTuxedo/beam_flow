# lib/beam_flow_web/components/media_selector_component.ex
defmodule BeamFlowWeb.Components.MediaSelectorComponent do
  @moduledoc """
  LiveComponent for selecting media for a post's featured image.
  """
  use BeamFlowWeb, :live_component

  alias BeamFlow.Content
  alias BeamFlowWeb.Components.MediaLibraryComponent
  alias BeamFlowWeb.Components.MediaUploaderComponent

  @impl true
  def update(%{selected_media_id: media_id} = _assigns, socket) do
    # Handle direct update of media_id
    socket =
      socket
      |> assign_new(:show_selector, fn -> false end)
      |> assign(:selected_media_id, media_id)
      |> assign_media()

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:selected_media_id, fn -> nil end)
      |> assign_new(:tab, fn -> "library" end)
      |> assign_new(:filter, fn -> %{content_type: "image/%"} end)
      |> assign_new(:show_selector, fn -> false end)
      |> assign_media()

    {:ok, socket}
  end

  defp assign_media(socket) do
    case socket.assigns.selected_media_id do
      nil -> assign(socket, :selected_media, nil)
      id -> assign(socket, :selected_media, Content.get_media!(id))
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="media-selector">
      <div class="mb-2 flex justify-between items-center">
        <label class="block text-sm font-semibold leading-6 text-zinc-800">Featured Image</label>

        <%= if @selected_media do %>
          <button
            type="button"
            phx-click="clear-selection"
            phx-target={@myself}
            class="text-sm text-red-600 hover:text-red-800"
          >
            Remove image
          </button>
        <% end %>
      </div>

      <%= if @selected_media do %>
        <div class="border rounded-md overflow-hidden bg-gray-50">
          <div class="aspect-video bg-gray-100 relative group">
            <img
              src={@selected_media.path}
              alt={@selected_media.alt_text || @selected_media.original_filename}
              class="w-full h-full object-cover"
            />
          </div>
          <div class="p-2">
            <p class="text-sm text-gray-700 truncate">
              {@selected_media.original_filename}
            </p>
          </div>
        </div>
      <% else %>
        <div
          phx-click="open-selector"
          phx-target={@myself}
          class="border-2 border-dashed border-gray-300 rounded-md py-8 px-4 text-center cursor-pointer hover:bg-gray-50"
        >
          <.icon name="hero-photo" class="h-10 w-10 text-gray-400 mx-auto" />
          <p class="mt-2 text-sm text-gray-600">Click to select an image</p>
        </div>
      <% end %>

      <.modal
        :if={@show_selector}
        id="media-selector-modal"
        show
        on_cancel={JS.push("close-selector", target: @myself)}
      >
        <div class="w-full max-w-4xl mx-auto">
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
              id="media-library"
              filter={@filter}
              current_user={@current_user}
              selected_media_id={@selected_media_id}
              target_component={@myself}
            />
          <% else %>
            <.live_component
              module={MediaUploaderComponent}
              id="media-uploader"
              current_user={@current_user}
              target_component={@myself}
            />
          <% end %>
        </div>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("open-selector", _params, socket) do
    {:noreply, assign(socket, :show_selector, true)}
  end

  @impl true
  def handle_event("close-selector", _params, socket) do
    {:noreply, assign(socket, :show_selector, false)}
  end

  @impl true
  def handle_event("change-tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab, tab)}
  end

  @impl true
  def handle_event("clear-selection", _params, socket) do
    socket =
      socket
      |> assign(:selected_media_id, nil)
      |> assign(:selected_media, nil)

    # Send event to parent about the selection change
    socket = push_event(socket, "featured-image-changed", %{id: nil})

    {:noreply, socket}
  end

  @impl true
  def handle_event("media-selected", %{"id" => media_id}, socket) do
    # Called from child component (MediaLibraryComponent)
    socket =
      socket
      |> assign(:selected_media_id, media_id)
      |> assign_media()
      |> assign(:show_selector, false)

    # Push event to parent about the selection change
    socket = push_event(socket, "featured-image-changed", %{id: media_id})

    {:noreply, socket}
  end

  @impl true
  def handle_event("media-uploaded", %{"id" => media_id}, socket) do
    # Called from child component (MediaUploaderComponent)
    socket =
      socket
      |> assign(:tab, "library")
      |> assign(:selected_media_id, media_id)
      |> assign_media()

    # Push event to parent about the selection change
    socket = push_event(socket, "featured-image-changed", %{id: media_id})

    {:noreply, socket}
  end
end
