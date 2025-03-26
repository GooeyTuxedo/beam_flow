defmodule BeamFlowWeb.Shared.PostLive.FormComponent do
  use BeamFlowWeb, :live_component

  alias BeamFlow.Content
  alias BeamFlowWeb.Components.MarkdownEditorComponent
  alias BeamFlowWeb.Components.MediaSelectorComponent

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto" id="post-form-container" phx-hook="PostFormHook">
      <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4" id={"#{@id}-title"}>
        {@title}
      </h3>

      <.simple_form
        for={@form}
        id="post-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="grid grid-cols-1 gap-y-6 gap-x-4 sm:grid-cols-6">
          <div class="sm:col-span-6">
            <.input field={@form[:title]} type="text" label="Title" />
          </div>

          <div class="sm:col-span-6">
            <.input
              field={@form[:slug]}
              type="text"
              label="Slug"
              placeholder="Leave blank to auto-generate from title"
            />
            <p class="mt-1 text-sm text-gray-500">
              URL-friendly identifier. Will be auto-generated if left blank.
            </p>
          </div>

          <div class="sm:col-span-6">
            <.input field={@form[:excerpt]} type="textarea" label="Excerpt" rows={2} />
            <p class="mt-1 text-sm text-gray-500">
              Brief summary of the post, used in listings and SEO.
            </p>
          </div>

          <div class="sm:col-span-6">
            <.live_component
              module={MediaSelectorComponent}
              id={"media-selector-#{@id}"}
              current_user={@current_user}
              selected_media_id={@featured_image_id}
              show_selector={false}
            />
          </div>
          
    <!-- Categories & Tags Selection -->
          <div class="sm:col-span-3">
            <label class="block text-sm font-semibold leading-6 text-zinc-800 mb-1">Categories</label>
            <div class="bg-white border rounded-md p-2 max-h-60 overflow-y-auto">
              <%= for category <- @categories do %>
                <div class="flex items-center mb-1">
                  <input
                    type="checkbox"
                    id={"category-#{category.id}"}
                    checked={category.id in @selected_category_ids}
                    phx-click="select-category"
                    phx-value-id={category.id}
                    phx-target={@myself}
                    class="mr-2"
                  />
                  <label for={"category-#{category.id}"} class="text-sm">{category.name}</label>
                </div>
              <% end %>
            </div>
          </div>

          <div class="sm:col-span-3">
            <label class="block text-sm font-semibold leading-6 text-zinc-800 mb-1">Tags</label>
            <div class="bg-white border rounded-md p-2 max-h-60 overflow-y-auto">
              <%= for tag <- @tags do %>
                <div class="flex items-center mb-1">
                  <input
                    type="checkbox"
                    id={"tag-#{tag.id}"}
                    checked={tag.id in @selected_tag_ids}
                    phx-click="select-tag"
                    phx-value-id={tag.id}
                    phx-target={@myself}
                    class="mr-2"
                  />
                  <label for={"tag-#{tag.id}"} class="text-sm">{tag.name}</label>
                </div>
              <% end %>
            </div>
          </div>

          <div class="sm:col-span-6">
            <label class="block text-sm font-semibold leading-6 text-zinc-800">Content</label>
            <.live_component
              module={MarkdownEditorComponent}
              id={"editor-#{@id}"}
              field_name={@form[:content].name}
              value={@form[:content].value}
              autosaved={@autosaved}
              current_user={@current_user}
            />
            <p class="mt-1 text-sm text-gray-500">
              Write your post content using Markdown.
            </p>
          </div>

          <div class="sm:col-span-3">
            <.input
              field={@form[:status]}
              type="select"
              label="Status"
              options={status_options()}
              phx-target={@myself}
              phx-change="toggle_scheduled"
            />
          </div>

          <%= if show_scheduled_at_field?(@form) do %>
            <div class="sm:col-span-3">
              <.input field={@form[:published_at]} type="datetime-local" label="Publish on" />
            </div>
          <% end %>
        </div>

        <:actions>
          <.button
            type="button"
            class="bg-white py-2 px-4 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
            phx-click={JS.patch(@return_to)}
          >
            Cancel
          </.button>
          <.button type="submit" class="ml-3">Save</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{post: post} = assigns, socket) do
    changeset = Content.change_post(post)
    categories = Content.list_categories()
    tags = Content.list_tags()
    selected_category_ids = extract_association_ids(post, :categories)
    selected_tag_ids = extract_association_ids(post, :tags)
    featured_image_id = post.featured_image_id

    # Assign all standard values
    socket =
      socket
      |> assign(assigns)
      |> assign(:autosaved, nil)
      |> assign(:categories, categories)
      |> assign(:tags, tags)
      |> assign(:selected_category_ids, selected_category_ids)
      |> assign(:selected_tag_ids, selected_tag_ids)
      |> assign(:featured_image_id, featured_image_id)
      |> assign_form(changeset)
      |> maybe_attach_media_hooks()

    {:ok, socket}
  end

  defp maybe_attach_media_hooks(socket) do
    return_socket = socket

    if connected?(socket) do
      attach_hook(socket, :media_selection, :handle_event, &handle_media_event/3)
    else
      return_socket
    end
  end

  defp handle_media_event("featured-image-changed", %{"id" => media_id}, socket) do
    media_id = if media_id == nil, do: nil, else: String.to_integer(media_id)
    {:halt, assign(socket, :featured_image_id, media_id)}
  end

  defp handle_media_event(_event, _params, socket) do
    {:cont, socket}
  end

  # Helper to safely extract IDs from associations that might not be loaded
  defp extract_association_ids(struct, association_name) do
    case Map.get(struct, association_name) do
      %Ecto.Association.NotLoaded{} -> []
      nil -> []
      list when is_list(list) -> Enum.map(list, & &1.id)
    end
  end

  @impl true
  def handle_event("select-category", %{"id" => id}, socket) do
    category_id = String.to_integer(id)
    selected_ids = toggle_selection(socket.assigns.selected_category_ids, category_id)

    {:noreply, assign(socket, :selected_category_ids, selected_ids)}
  end

  @impl true
  def handle_event("select-tag", %{"id" => id}, socket) do
    tag_id = String.to_integer(id)
    selected_ids = toggle_selection(socket.assigns.selected_tag_ids, tag_id)

    {:noreply, assign(socket, :selected_tag_ids, selected_ids)}
  end

  @impl true
  def handle_event("autosave", %{"content" => content}, socket) do
    current_changeset = socket.assigns.form.source
    updated_changeset = Ecto.Changeset.put_change(current_changeset, :content, content)

    socket_with_form = assign_form(socket, updated_changeset)
    socket_with_autosave = assign(socket_with_form, :autosaved, DateTime.utc_now())

    {:noreply, socket_with_autosave}
  end

  @impl true
  def handle_event("validate", %{"post" => post_params}, socket) do
    # Handle datetime conversion if it's a scheduled post
    post_params = process_scheduled_datetime(post_params)

    changeset =
      socket.assigns.post
      |> Content.change_post(post_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("toggle_scheduled", %{"post" => %{"status" => status}}, socket) do
    # When status changes to "scheduled", we might want to set a default time
    # if none is present yet
    changeset = socket.assigns.form.source

    if status == "scheduled" && !get_field_value(changeset, :published_at) do
      default_time =
        DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)

      changeset =
        changeset
        |> Ecto.Changeset.put_change(:published_at, default_time)

      {:noreply, assign_form(socket, changeset)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("save", %{"post" => post_params}, socket) do
    # Handle datetime conversion if it's a scheduled post
    post_params = process_scheduled_datetime(post_params)

    # Ensure the current user is set as the author if it's a new post
    post_params =
      if is_nil(socket.assigns.post.id) do
        Map.put_new(post_params, "user_id", socket.assigns.current_user.id)
      else
        post_params
      end

    # Add category, tag, and featured image IDs to params
    post_params =
      post_params
      |> Map.put("category_ids", socket.assigns.selected_category_ids)
      |> Map.put("tag_ids", socket.assigns.selected_tag_ids)
      |> Map.put("featured_image_id", socket.assigns.featured_image_id)

    save_post(socket, socket.assigns.action, post_params)
  end

  defp save_post(socket, :edit, post_params) do
    case Content.update_post(socket.assigns.post, post_params) do
      {:ok, _post} ->
        {:noreply,
         socket
         |> put_flash(:info, "Post updated successfully")
         |> push_event("changes-saved", %{})
         |> push_patch(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_post(socket, :new, post_params) do
    case Content.create_post(post_params) do
      {:ok, _post} ->
        {:noreply,
         socket
         |> put_flash(:info, "Post created successfully")
         |> push_event("changes-saved", %{})
         |> push_patch(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  # Helper functions

  defp status_options do
    [
      {"Draft", "draft"},
      {"Published", "published"},
      {"Scheduled", "scheduled"}
    ]
  end

  defp show_scheduled_at_field?(form) do
    form[:status].value == "scheduled"
  end

  # Get a field value from a changeset
  defp get_field_value(changeset, field) do
    Ecto.Changeset.get_field(changeset, field)
  end

  # Process scheduled datetime for the params
  defp process_scheduled_datetime(post_params) do
    if post_params["status"] == "scheduled" do
      # If it's a scheduled post but no published_at is set, default to 1 hour from now
      if !post_params["published_at"] || post_params["published_at"] == "" do
        default_time =
          DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)

        Map.put(post_params, "published_at", default_time)
      else
        post_params
      end
    else
      # For non-scheduled posts, published_at is handled at the model level
      post_params
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp toggle_selection(selected_ids, id) do
    if id in selected_ids do
      List.delete(selected_ids, id)
    else
      [id | selected_ids]
    end
  end
end
