defmodule BeamFlowWeb.Components.MarkdownEditorComponent do
  @moduledoc """
  LiveComponent for a markdown editor with live preview and formatting toolbar.
  Provides real-time markdown rendering and autosave functionality.
  """
  use BeamFlowWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="markdown-editor" id={"markdown-editor-#{@id}"} phx-hook="MarkdownEditor">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div class="editor-area">
          <div class="toolbar mb-2 p-2 bg-gray-100 rounded-t-md border border-gray-300 flex items-center space-x-1">
            <.button
              type="button"
              phx-click="markdown-format"
              phx-value-format="bold"
              phx-target={@myself}
              class="bg-transparent p-1 hover:bg-gray-200 text-gray-700"
            >
              <.icon name="hero-bold" class="h-5 w-5" />
            </.button>
            <.button
              type="button"
              phx-click="markdown-format"
              phx-value-format="italic"
              phx-target={@myself}
              class="bg-transparent p-1 hover:bg-gray-200 text-gray-700"
            >
              <.icon name="hero-code-bracket" class="h-5 w-5" />
            </.button>
            <.button
              type="button"
              phx-click="markdown-format"
              phx-value-format="heading"
              phx-target={@myself}
              class="bg-transparent p-1 hover:bg-gray-200 text-gray-700"
            >
              <.icon name="hero-heading" class="h-5 w-5" />
            </.button>
            <.button
              type="button"
              phx-click="markdown-format"
              phx-value-format="link"
              phx-target={@myself}
              class="bg-transparent p-1 hover:bg-gray-200 text-gray-700"
            >
              <.icon name="hero-link" class="h-5 w-5" />
            </.button>
            <.button
              type="button"
              phx-click="open-media-selector"
              phx-target={@myself}
              class="bg-transparent p-1 hover:bg-gray-200 text-gray-700"
            >
              <.icon name="hero-photo" class="h-5 w-5" />
            </.button>
            <.button
              type="button"
              phx-click="markdown-format"
              phx-value-format="list"
              phx-target={@myself}
              class="bg-transparent p-1 hover:bg-gray-200 text-gray-700"
            >
              <.icon name="hero-list-bullet" class="h-5 w-5" />
            </.button>
            <div class="border-l border-gray-300 h-6 mx-1"></div>
            <.button
              type="button"
              phx-click="toggle-preview"
              phx-target={@myself}
              class="bg-transparent p-1 hover:bg-gray-200 text-gray-700"
            >
              <.icon name="hero-eye" class="h-5 w-5" />
            </.button>
          </div>
          <.input
            id={"markdown-input-#{@id}"}
            name={@field_name}
            value={@value}
            type="textarea"
            rows="10"
            phx-target={@myself}
            phx-debounce="300"
            placeholder="Write your content in Markdown format..."
            class="font-mono"
          />
          <div class="mt-1">
            <div id={"editor-status-#{@id}"} class="text-sm text-gray-500 italic">
              <%= if @autosaved do %>
                <span class="text-green-600">Last saved at {format_time(@autosaved)}</span>
              <% else %>
                <span>Start typing...</span>
              <% end %>
            </div>
          </div>
        </div>
        <div
          class="preview-area"
          class={"#{if @show_preview, do: "block", else: "hidden"} md:block"}
          id={"markdown-preview-#{@id}"}
        >
          <div class="p-2 bg-gray-100 rounded-t-md border border-gray-300 mb-2">
            <span class="text-sm font-medium text-gray-600">Preview</span>
          </div>
          <div class="border border-gray-300 rounded-b-md p-4 prose max-w-none h-64 overflow-y-auto">
            {raw(@html_preview)}
          </div>
        </div>
      </div>

      <.modal
        :if={@show_media_selector}
        id={"media-selector-modal-#{@id}"}
        show
        on_cancel={JS.push("close-media-selector", target: @myself)}
      >
        <div class="w-full max-w-4xl mx-auto">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Insert Media</h3>
          <.live_component
            module={BeamFlowWeb.Components.MarkdownMediaSelector}
            id={"markdown-media-selector-#{@id}"}
            current_user={@current_user}
            target_component={@myself}
          />
        </div>
      </.modal>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:autosaved, fn -> nil end)
      |> assign_new(:show_preview, fn -> true end)
      |> assign_new(:show_media_selector, fn -> false end)
      |> assign_new(:current_user, fn -> assigns[:current_user] end)
      |> assign_html_preview()

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle-preview", _params, socket) do
    {:noreply, assign(socket, :show_preview, !socket.assigns.show_preview)}
  end

  @impl true
  def handle_event("content-changed", %{"value" => value}, socket) do
    socket =
      socket
      |> assign(:value, value)
      |> assign_html_preview()
      |> assign(:autosaved, DateTime.utc_now())

    {:noreply,
     push_event(socket, "editor-content-changed", %{id: socket.assigns.id, content: value})}
  end

  @impl true
  def handle_event("markdown-format", %{"format" => format}, socket) do
    {:noreply, push_event(socket, "markdown-format", %{format: format})}
  end

  @impl true
  def handle_event("open-media-selector", _params, socket) do
    {:noreply, assign(socket, :show_media_selector, true)}
  end

  @impl true
  def handle_event("close-media-selector", _params, socket) do
    {:noreply, assign(socket, :show_media_selector, false)}
  end

  @impl true
  def handle_event("media-selected", %{"id" => media_id}, socket) do
    # Get the media details
    media = BeamFlow.Content.get_media!(media_id)

    # Send event to the JS hook
    socket =
      socket
      |> assign(:show_media_selector, false)
      |> push_event("media-selected-for-editor", %{
        id: media.id,
        path: media.path,
        content_type: media.content_type,
        original_filename: media.original_filename,
        alt_text: media.alt_text || media.original_filename
      })

    {:noreply, socket}
  end

  defp assign_html_preview(socket) do
    html = markdown_to_html(socket.assigns.value)
    assign(socket, :html_preview, html)
  end

  defp markdown_to_html(nil), do: ""
  defp markdown_to_html(""), do: ""

  defp markdown_to_html(markdown) do
    # Process markdown to HTML using earmark
    {:ok, html, _warnings} =
      Earmark.as_html(markdown, %Earmark.Options{
        code_class_prefix: "language-",
        smartypants: true
      })

    HtmlSanitizeEx.html5(html)
  end

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S")
  end
end
