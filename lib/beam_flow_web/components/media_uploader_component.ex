defmodule BeamFlowWeb.Components.MediaUploaderComponent do
  @moduledoc """
  LiveComponent for handling media uploads with drag-and-drop support,
  preview, and proper validation.
  """
  use BeamFlowWeb, :live_component

  alias BeamFlow.Content
  alias BeamFlow.Content.Media

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:target_component, fn -> nil end)
      |> allow_upload(:media,
        accept: ~w(.jpg .jpeg .png .gif .svg .pdf),
        max_entries: 5,
        max_file_size: Media.max_file_size(),
        auto_upload: true
      )
      |> assign(:uploads_finished, Map.get(assigns, :uploads_finished, false))
      |> assign(:uploaded_files, Map.get(assigns, :uploaded_files, []))

    # Handle special uploads_finished case
    if assigns[:uploads_finished] && assigns[:uploaded_files] &&
         length(assigns[:uploaded_files]) > 0 do
      media_ids = Enum.map(assigns[:uploaded_files], & &1.id)

      target = socket.assigns.target_component

      if target && Enum.at(media_ids, 0) do
        # Send to parent component
        send_update(target, id: target.id, event: "media-uploaded", id: Enum.at(media_ids, 0))
      else
        # Send to parent LiveView
        push_event(socket, "media-uploaded", %{ids: media_ids})
      end
    end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-medium text-gray-900">Upload Media</h3>
      </div>

      <form id="upload-form" phx-submit="save" phx-change="validate" phx-target={@myself}>
        <div
          class="flex justify-center rounded-lg border border-dashed border-gray-300 px-6 py-10"
          phx-drop-target={@uploads.media.ref}
        >
          <div class="text-center">
            <.icon name="hero-photo" class="mx-auto h-12 w-12 text-gray-300" />
            <div class="mt-4 flex text-sm leading-6 text-gray-600">
              <label
                for={@uploads.media.ref}
                class="relative cursor-pointer rounded-md bg-white font-semibold text-indigo-600 focus-within:outline-none focus-within:ring-2 focus-within:ring-indigo-600 focus-within:ring-offset-2 hover:text-indigo-500"
              >
                <span>Upload files</span>
                <.live_file_input upload={@uploads.media} class="sr-only" />
              </label>
              <p class="pl-1">or drag and drop</p>
            </div>
            <p class="text-xs leading-5 text-gray-600 mt-2">
              JPG, PNG, GIF, SVG, PDF up to {trunc(Media.max_file_size() / 1_048_576)}MB
            </p>
          </div>
        </div>

        <%= for entry <- @uploads.media.entries do %>
          <div class="mt-4 flex items-center justify-between bg-gray-50 p-4 rounded-md">
            <div class="flex items-center gap-4">
              <%= if image?(entry.client_type) do %>
                <.live_img_preview entry={entry} width="48" class="rounded" />
              <% else %>
                <.icon name="hero-document" class="h-12 w-12 text-gray-400" />
              <% end %>
              <div>
                <p class="text-sm font-medium">{entry.client_name}</p>
                <p class="text-xs text-gray-500">
                  {entry.client_type} • {format_bytes(entry.client_size)}
                </p>
                <%= if upload_error_message(@uploads.media, entry) do %>
                  <p class="text-xs text-red-500">
                    {upload_error_message(@uploads.media, entry)}
                  </p>
                <% end %>
              </div>
            </div>
            <div class="flex items-center">
              <div class="mr-4 w-20 bg-gray-200 rounded-full h-2.5">
                <div class="bg-indigo-600 h-2.5 rounded-full" style={"width: #{entry.progress}%"}>
                </div>
              </div>
              <button
                type="button"
                phx-click="cancel-upload"
                phx-value-ref={entry.ref}
                phx-target={@myself}
                class="text-red-600 hover:text-red-800"
              >
                <.icon name="hero-x-mark" class="h-5 w-5" />
              </button>
            </div>
          </div>
        <% end %>

        <%= if @uploads_finished && length(@uploaded_files) > 0 do %>
          <div class="mt-4 p-4 bg-green-50 rounded-md">
            <p class="text-green-700 flex items-center">
              <.icon name="hero-check-circle" class="h-5 w-5 mr-2" />
              Successfully uploaded {length(@uploaded_files)} files
            </p>
          </div>
        <% end %>
      </form>
    </div>
    """
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :media, ref)}
  end

  @impl true
  def handle_event("save", _params, socket) do
    {:noreply, socket}
  end

  # Hook for upload progress tracking
  def handle_progress(:media, entry, socket) do
    if entry.done? do
      uploaded_files =
        consume_uploaded_entries(socket, :media, fn %{path: path}, entry ->
          create_media_from_upload(path, entry, socket.assigns.current_user)
        end)

      uploaded_files = Enum.filter(uploaded_files, &(&1 != :error))

      socket =
        socket
        |> update(:uploaded_files, fn existing -> existing ++ uploaded_files end)
        |> assign(:uploads_finished, true)

      # Update self with the new state
      send_update(__MODULE__,
        id: socket.assigns.id,
        uploads_finished: true,
        uploaded_files: uploaded_files
      )

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # Helper function to reduce nesting
  defp create_media_from_upload(path, entry, current_user) do
    attrs = %{
      user_id: current_user.id,
      alt_text: entry.client_name,
      current_user: current_user
    }

    case Content.create_media_from_upload(
           %{
             path: path,
             content_type: entry.client_type,
             client_name: entry.client_name,
             size: entry.client_size
           },
           attrs
         ) do
      {:ok, media} -> {:ok, media}
      {:error, _reason} -> :error
    end
  end

  defp image?(content_type) do
    String.starts_with?(content_type, "image/")
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

  defp upload_error_message(upload, entry) do
    case upload_errors(upload, entry) do
      [{:too_large, max}] -> "File exceeds maximum size of #{format_bytes(max)}"
      [{:not_accepted, _reason}] -> "File type not accepted"
      [] -> nil
      errors -> "Error: #{inspect(errors)}"
    end
  end
end
