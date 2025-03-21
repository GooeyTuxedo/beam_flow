defmodule BeamFlowWeb.Shared.PostLive.FormComponent do
  use BeamFlowWeb, :live_component

  alias BeamFlow.Content

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto">
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
            <.input
              field={@form[:content]}
              type="textarea"
              label="Content"
              rows={12}
              placeholder="Write your post content in Markdown format"
            />
            <p class="mt-1 text-sm text-gray-500">
              Write your post content using Markdown. A rich editor will be available in future updates.
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

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
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

    save_post(socket, socket.assigns.action, post_params)
  end

  defp save_post(socket, :edit, post_params) do
    case Content.update_post(socket.assigns.post, post_params) do
      {:ok, _post} ->
        {:noreply,
         socket
         |> put_flash(:info, "Post updated successfully")
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
end
