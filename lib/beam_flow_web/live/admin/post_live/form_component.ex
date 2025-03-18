defmodule BeamFlowWeb.Admin.PostLive.FormComponent do
  use BeamFlowWeb, :live_component

  alias BeamFlow.Content
  alias BeamFlowWeb.Admin.PostLive.Helpers

  import BeamFlowWeb.CoreComponents

  @impl true
  def update(%{post: post} = assigns, socket) do
    changeset = Content.change_post(post)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)
     |> assign(:status_options, Helpers.status_options())
     |> assign(:scheduled_at, scheduled_datetime(post))}
  end

  @impl true
  def handle_event("validate", %{"post" => post_params}, socket) do
    # Handle scheduled publishing datetime
    post_params = process_scheduled_datetime(post_params, socket.assigns.scheduled_at)

    changeset =
      socket.assigns.post
      |> Content.change_post(post_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"post" => post_params}, socket) do
    # Handle scheduled publishing datetime
    post_params = process_scheduled_datetime(post_params, socket.assigns.scheduled_at)

    # Ensure the current user is set as the author if it's a new post
    post_params =
      if is_nil(socket.assigns.post.id) do
        Map.put_new(post_params, "user_id", socket.assigns.current_user.id)
      else
        post_params
      end

    save_post(socket, socket.assigns.action, post_params)
  end

  @impl true
  def handle_event("toggle-scheduled", _params, socket) do
    status = Ecto.Changeset.get_field(socket.assigns.changeset, :status)

    scheduled_at =
      if status == "scheduled",
        do: socket.assigns.scheduled_at || default_scheduled_time(),
        else: nil

    {:noreply, assign(socket, :scheduled_at, scheduled_at)}
  end

  defp save_post(socket, :edit, post_params) do
    case Content.update_post(socket.assigns.post, post_params) do
      {:ok, _post} ->
        {:noreply,
         socket
         |> put_flash(:info, "Post updated successfully")
         |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_post(socket, :new, post_params) do
    case Content.create_post(post_params) do
      {:ok, _post} ->
        {:noreply,
         socket
         |> put_flash(:info, "Post created successfully")
         |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  # Get scheduled datetime from a post
  defp scheduled_datetime(post) do
    if post.status == "scheduled" and post.published_at, do: post.published_at, else: nil
  end

  # Default time for scheduling (1 hour from now)
  defp default_scheduled_time do
    DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)
  end

  # Process the scheduled datetime for the params
  defp process_scheduled_datetime(post_params, scheduled_at) do
    if post_params["status"] == "scheduled" && scheduled_at do
      Map.put(post_params, "published_at", scheduled_at)
    else
      post_params
    end
  end
end
