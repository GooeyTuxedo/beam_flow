defmodule BeamFlowWeb.Admin.MediaLive.FormComponent do
  use BeamFlowWeb, :live_component

  alias BeamFlow.Content

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Edit media metadata</:subtitle>
      </.header>

      <.simple_form
        :let={f}
        for={@changeset}
        id="media-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="grid grid-cols-1 gap-6 mb-8">
          <div class="aspect-video bg-gray-100 mx-auto border rounded-md overflow-hidden">
            <%= if String.starts_with?(@media.content_type, "image/") do %>
              <img src={@media.path} alt={@media.alt_text} class="object-contain w-full h-full" />
            <% else %>
              <div class="flex items-center justify-center h-full">
                <.icon name="hero-document" class="h-16 w-16 text-gray-400" />
                <p class="ml-2 text-sm text-gray-600">{@media.original_filename}</p>
              </div>
            <% end %>
          </div>

          <.input field={f[:alt_text]} type="text" label="Alt Text" />
          <.input field={f[:original_filename]} type="text" label="Filename" />

          <div class="space-y-2">
            <label class="text-sm font-semibold leading-6 text-zinc-800">File Info</label>
            <div class="rounded-md bg-gray-50 p-4 text-sm text-gray-700 shadow-sm ring-1 ring-gray-200">
              <p><strong>Content Type:</strong> {@media.content_type}</p>
              <p><strong>Size:</strong> {format_bytes(@media.size)}</p>
              <p><strong>Path:</strong> {@media.path}</p>
              <p><strong>Uploaded by:</strong> {@media.user.email}</p>
              <p>
                <strong>Created:</strong> {Calendar.strftime(@media.inserted_at, "%b %d, %Y at %H:%M")}
              </p>
            </div>
          </div>
        </div>

        <:actions>
          <.button phx-disable-with="Saving...">Save changes</.button>
          <.link patch={@return_to} class="btn btn-outline ml-2">Cancel</.link>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{media: media} = assigns, socket) do
    changeset = Content.change_media(media)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"media" => media_params}, socket) do
    changeset =
      socket.assigns.media
      |> Content.change_media(media_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"media" => media_params}, socket) do
    media_params = Map.put(media_params, :current_user, socket.assigns.current_user)

    case Content.update_media(socket.assigns.media, media_params) do
      {:ok, _media} ->
        Phoenix.PubSub.broadcast(BeamFlow.PubSub, "media:updates", :media_updated)

        {:noreply,
         socket
         |> put_flash(:info, "Media updated successfully")
         |> push_patch(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp format_bytes(bytes) when bytes < 1024 do
    "#{bytes} B"
  end

  defp format_bytes(bytes) when bytes < 1_048_576 do
    "#{Float.round(bytes / 1024, 1)} KB"
  end

  defp format_bytes(bytes) do
    "#{Float.round(bytes / 1_048_576, 1)} MB"
  end
end
