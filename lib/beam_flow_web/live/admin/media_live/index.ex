# lib/beam_flow_web/live/admin/media_live/index.ex
defmodule BeamFlowWeb.Admin.MediaLive.Index do
  use BeamFlowWeb, :live_view

  alias BeamFlow.Content
  alias BeamFlow.Content.Media
  alias BeamFlowWeb.Components.MediaUploaderComponent

  @impl true
  def mount(_params, _session, socket) do
    # Set up event listeners for media upload notifications
    if connected?(socket) do
      ^socket =
        socket
        |> attach_hook(:media_events, :handle_event, fn
          "media-uploaded", %{"ids" => _media_ids}, socket ->
            {:halt, fetch_media(socket)}

          _event, _params, socket ->
            {:cont, socket}
        end)
    end

    {:ok, socket |> assign(:media_items, []) |> fetch_media()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Media Library")
    |> assign(:media, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Upload Media")
    |> assign(:media, %Media{})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Media")
    |> assign(:media, Content.get_media!(id))
  end

  defp fetch_media(socket) do
    criteria = [{:order_by, {:inserted_at, :desc}}]
    media_items = Content.list_media(criteria)
    assign(socket, :media_items, media_items)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    media = Content.get_media!(id)
    {:ok, _delete} = Content.delete_media(media, socket.assigns.current_user)

    # Use push events instead of PubSub for tracking changes
    socket = push_event(socket, "media-deleted", %{id: id})

    {:noreply, socket |> put_flash(:info, "Media deleted successfully") |> fetch_media()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-2xl font-semibold text-gray-900">Media Library</h1>
        <.link patch={~p"/admin/media/new"} class="btn btn-primary">
          <.icon name="hero-plus" class="w-5 h-5 mr-1" /> Upload Media
        </.link>
      </div>

      <.modal
        :if={@live_action in [:new]}
        id="media-modal"
        show
        on_cancel={JS.patch(~p"/admin/media")}
      >
        <.live_component
          module={MediaUploaderComponent}
          id="media-uploader"
          current_user={@current_user}
        />
      </.modal>

      <.modal
        :if={@live_action in [:edit]}
        id="media-edit-modal"
        show
        on_cancel={JS.patch(~p"/admin/media")}
      >
        <.live_component
          module={BeamFlowWeb.Admin.MediaLive.FormComponent}
          id="media-form"
          media={@media}
          current_user={@current_user}
          return_to={~p"/admin/media"}
          title="Edit Media"
        />
      </.modal>

      <div class="mt-6">
        <%= if Enum.empty?(@media_items) do %>
          <div class="text-center py-12 border-2 border-dashed border-gray-300 rounded-md">
            <.icon name="hero-photo" class="h-12 w-12 text-gray-400 mx-auto" />
            <h3 class="mt-2 text-sm font-medium text-gray-900">No media files</h3>
            <p class="mt-1 text-sm text-gray-500">Get started by uploading your first media file.</p>
            <div class="mt-6">
              <.link patch={~p"/admin/media/new"} class="btn btn-primary">
                <.icon name="hero-plus" class="w-5 h-5 mr-1" /> Upload Media
              </.link>
            </div>
          </div>
        <% else %>
          <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
            <%= for media <- @media_items do %>
              <div class="bg-white rounded-lg shadow overflow-hidden">
                <div class="aspect-video bg-gray-100 relative group">
                  <%= if String.starts_with?(media.content_type, "image/") do %>
                    <img
                      src={media.path}
                      alt={media.alt_text || media.original_filename}
                      class="w-full h-full object-cover"
                    />
                  <% else %>
                    <div class="flex items-center justify-center h-full">
                      <.icon name="hero-document" class="h-16 w-16 text-gray-400" />
                    </div>
                  <% end %>
                  <div class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-30 transition-all flex items-center justify-center opacity-0 group-hover:opacity-100">
                    <.link
                      href={media.path}
                      target="_blank"
                      class="p-2 bg-white rounded-full shadow-md mx-1 hover:bg-gray-100"
                      title="View"
                    >
                      <.icon name="hero-eye" class="h-5 w-5 text-gray-600" />
                    </.link>
                    <.link
                      patch={~p"/admin/media/#{media.id}/edit"}
                      class="p-2 bg-white rounded-full shadow-md mx-1 hover:bg-gray-100"
                      title="Edit"
                    >
                      <.icon name="hero-pencil" class="h-5 w-5 text-blue-600" />
                    </.link>
                    <button
                      phx-click="delete"
                      phx-value-id={media.id}
                      data-confirm="Are you sure you want to delete this media file? This cannot be undone."
                      class="p-2 bg-white rounded-full shadow-md mx-1 hover:bg-gray-100"
                      title="Delete"
                    >
                      <.icon name="hero-trash" class="h-5 w-5 text-red-600" />
                    </button>
                  </div>
                </div>
                <div class="p-4">
                  <p
                    class="text-sm font-medium text-gray-900 truncate"
                    title={media.original_filename}
                  >
                    {media.original_filename}
                  </p>
                  <p class="text-xs text-gray-500 mt-1">
                    {media.content_type} • {format_bytes(media.size)}
                  </p>
                  <p class="text-xs text-gray-500 mt-1">
                    Uploaded by {media.user.email} on {format_date(media.inserted_at)}
                  </p>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_bytes(bytes) when bytes == 0, do: "0 B"

  defp format_bytes(bytes) when bytes < 1024 do
    "#{bytes} B"
  end

  defp format_bytes(bytes) when bytes < 1_048_576 do
    "#{Float.round(bytes / 1024, 1)} KB"
  end

  defp format_bytes(bytes) do
    "#{Float.round(bytes / 1_048_576, 1)} MB"
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end
end
