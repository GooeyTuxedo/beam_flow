defmodule BeamFlowWeb.Components.MediaLibraryComponent do
  @moduledoc """
  LiveComponent for browsing and selecting media items.
  """
  use BeamFlowWeb, :live_component

  alias BeamFlow.Content

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_defaults()
      |> fetch_media()

    {:ok, socket}
  end

  defp assign_defaults(socket) do
    socket
    |> assign_new(:filter, fn -> %{} end)
    |> assign_new(:selected_media_id, fn -> nil end)
    |> assign_new(:allow_multiple, fn -> false end)
    |> assign_new(:selected_media_ids, fn -> [] end)
    |> assign_new(:readonly, fn -> false end)
    |> assign_new(:target_component, fn -> nil end)
  end

  defp fetch_media(socket) do
    criteria = build_criteria(socket.assigns.filter)
    media_items = Content.list_media(criteria)

    assign(socket, :media_items, media_items)
  end

  defp build_criteria(filter) do
    criteria = []

    criteria =
      if Map.has_key?(filter, :user_id) do
        [{:user_id, filter.user_id} | criteria]
      else
        criteria
      end

    criteria =
      if Map.has_key?(filter, :content_type) do
        [{:content_type, filter.content_type} | criteria]
      else
        criteria
      end

    criteria =
      if Map.has_key?(filter, :search) && filter.search != "" do
        [{:search, filter.search} | criteria]
      else
        criteria
      end

    [{:order_by, {:inserted_at, :desc}} | criteria]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white p-4 rounded-md shadow">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-medium text-gray-900">Media Library</h3>
        <div class="flex items-center space-x-2">
          <div class="relative">
            <input
              type="text"
              placeholder="Search..."
              value={Map.get(@filter, :search, "")}
              phx-keyup="search"
              phx-target={@myself}
              class="px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
            />
            <div class="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none">
              <.icon name="hero-magnifying-glass" class="h-4 w-4 text-gray-400" />
            </div>
          </div>
          <select
            phx-change="filter-type"
            phx-target={@myself}
            class="px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
          >
            <option value="">All Types</option>
            <option value="image">Images</option>
            <option value="application">Documents</option>
          </select>
        </div>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
        <%= for media <- @media_items do %>
          <div
            phx-click={
              unless @readonly, do: JS.push("select-media", value: %{id: media.id}, target: @myself)
            }
            class={[
              "border rounded-md overflow-hidden cursor-pointer bg-white transition",
              if(
                (@allow_multiple && media.id in @selected_media_ids) ||
                  (!@allow_multiple && @selected_media_id == media.id),
                do: "ring-2 ring-offset-2 ring-indigo-500",
                else: "hover:shadow-md"
              ),
              if(@readonly, do: "cursor-default")
            ]}
          >
            <div class="aspect-video bg-gray-100 flex items-center justify-center">
              <%= if String.starts_with?(media.content_type, "image/") do %>
                <img
                  src={media.path}
                  alt={media.alt_text || media.original_filename}
                  class="object-cover w-full h-full"
                />
              <% else %>
                <div class="text-center p-4">
                  <.icon name="hero-document-text" class="h-10 w-10 text-gray-400 mx-auto" />
                  <p class="mt-2 text-xs text-gray-500 truncate">{media.original_filename}</p>
                </div>
              <% end %>
            </div>
            <div class="p-2">
              <p class="text-xs text-gray-700 truncate" title={media.original_filename}>
                {media.original_filename}
              </p>
              <p class="text-xs text-gray-500">
                {format_date(media.inserted_at)} • {format_size(media.size)}
              </p>
            </div>
          </div>
        <% end %>

        <%= if Enum.empty?(@media_items) do %>
          <div class="col-span-full text-center py-12 text-gray-500">
            <.icon name="hero-photo" class="mx-auto h-12 w-12 text-gray-300" />
            <h3 class="mt-2 text-sm font-semibold text-gray-900">No media found</h3>
            <p class="mt-1 text-sm text-gray-500">
              <%= if Map.get(@filter, :search) do %>
                No results for your search
              <% else %>
                Upload some media files to get started
              <% end %>
            </p>
          </div>
        <% end %>
      </div>

      <%= if @allow_multiple && !@readonly do %>
        <div class="mt-4 flex justify-end">
          <.button
            phx-click="confirm-selection"
            phx-target={@myself}
            disabled={Enum.empty?(@selected_media_ids)}
            class="bg-indigo-600 hover:bg-indigo-700"
          >
            Select ({length(@selected_media_ids)})
          </.button>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("search", %{"value" => search_term}, socket) do
    filter = Map.put(socket.assigns.filter, :search, search_term)
    {:noreply, socket |> assign(:filter, filter) |> fetch_media()}
  end

  @impl true
  def handle_event("filter-type", %{"value" => ""}, socket) do
    filter = Map.delete(socket.assigns.filter, :content_type)
    {:noreply, socket |> assign(:filter, filter) |> fetch_media()}
  end

  @impl true
  def handle_event("filter-type", %{"value" => "image"}, socket) do
    filter = Map.put(socket.assigns.filter, :content_type, "image/%")
    {:noreply, socket |> assign(:filter, filter) |> fetch_media()}
  end

  @impl true
  def handle_event("filter-type", %{"value" => "application"}, socket) do
    filter = Map.put(socket.assigns.filter, :content_type, "application/%")
    {:noreply, socket |> assign(:filter, filter) |> fetch_media()}
  end

  @impl true
  def handle_event("select-media", %{"id" => id}, socket) do
    media_id = String.to_integer(id)

    socket =
      if socket.assigns.allow_multiple do
        selected_ids = socket.assigns.selected_media_ids

        selected_ids =
          if media_id in selected_ids do
            List.delete(selected_ids, media_id)
          else
            [media_id | selected_ids]
          end

        assign(socket, :selected_media_ids, selected_ids)
      else
        # For single selection, update local state
        socket = assign(socket, :selected_media_id, media_id)

        # Send event to parent/target component
        target = socket.assigns.target_component

        if target do
          send_update(target, id: target.id, event: "media-selected", id: media_id)
        else
          # Send directly to parent LiveView if no target component specified
          ^socket = push_event(socket, "media-selected", %{id: media_id})
        end

        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("confirm-selection", _params, socket) do
    if socket.assigns.allow_multiple do
      target = socket.assigns.target_component

      if target do
        send_update(target,
          id: target.id,
          event: "media-multiple-selected",
          ids: socket.assigns.selected_media_ids
        )
      else
        ^socket =
          push_event(socket, "media-multiple-selected", %{ids: socket.assigns.selected_media_ids})
      end
    end

    {:noreply, socket}
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  defp format_size(size) when size < 1024 do
    "#{size} B"
  end

  defp format_size(size) when size < 1_048_576 do
    "#{Float.round(size / 1024, 1)} KB"
  end

  defp format_size(size) do
    "#{Float.round(size / 1_048_576, 1)} MB"
  end
end
