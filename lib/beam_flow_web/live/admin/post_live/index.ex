defmodule BeamFlowWeb.Admin.PostLive.Index do
  use BeamFlowWeb, :live_view

  alias BeamFlow.Content
  alias BeamFlow.Content.Post
  alias BeamFlow.Roles
  alias BeamFlowWeb.Admin.PostLive.Helpers

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Posts")
      |> assign(:filter, %{"status" => nil, "search" => nil})
      |> assign_posts()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:post, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Post")
    |> assign(:post, %Post{})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    post = Content.get_post!(id)

    socket
    |> assign(:page_title, "Edit Post: #{post.title}")
    |> assign(:post, post)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    post = Content.get_post!(id)
    current_user = socket.assigns.current_user

    if can_delete_post?(current_user, post) do
      {:ok, _post} = Content.delete_post(post)

      {:noreply,
       socket
       |> put_flash(:info, "Post deleted successfully")
       |> assign_posts()}
    else
      {:noreply,
       socket
       |> put_flash(:error, "You don't have permission to delete this post")
       |> assign_posts()}
    end
  end

  @impl true
  def handle_event("publish", %{"id" => id}, socket) do
    post = Content.get_post!(id)
    current_user = socket.assigns.current_user

    if can_publish_post?(current_user, post) do
      {:ok, _post} = Content.publish_post(post)

      {:noreply,
       socket
       |> put_flash(:info, "Post published successfully")
       |> assign_posts()}
    else
      {:noreply,
       socket
       |> put_flash(:error, "You don't have permission to publish this post")
       |> assign_posts()}
    end
  end

  @impl true
  def handle_event("filter", %{"filter" => filter}, socket) do
    {:noreply,
     socket
     |> assign(:filter, filter)
     |> assign_posts()}
  end

  defp assign_posts(socket) do
    socket = BeamFlowWeb.LiveAuth.assign_user_roles(socket)

    filter = socket.assigns.filter
    criteria = build_criteria(filter, socket.assigns.current_user)
    assign(socket, :posts, Content.list_posts(criteria))
  end

  # Permission check helpers that work with the Roles module
  defp can_delete_post?(%{role: role}, _post) when role in [:admin, :editor], do: true

  defp can_delete_post?(%{id: user_id} = user, %{user_id: post_user_id}) do
    user_id == post_user_id && Roles.has_role?(user, :author)
  end

  defp can_delete_post?(_user, _post), do: false

  defp can_publish_post?(%{role: role}, _post) when role in [:admin, :editor], do: true
  defp can_publish_post?(%{id: user_id}, %{user_id: post_user_id}), do: user_id == post_user_id
  defp can_publish_post?(_user, _post), do: false

  defp build_criteria(filter, user) do
    criteria = []

    criteria =
      if filter["status"] && filter["status"] != "",
        do: [{:status, filter["status"]} | criteria],
        else: criteria

    criteria =
      if filter["search"] && filter["search"] != "",
        do: [{:search, filter["search"]} | criteria],
        else: criteria

    # If the user doesn't have admin or editor privileges, only show their posts
    unless Roles.has_role?(user, :editor) do
      ^criteria = [{:user_id, user.id} | criteria]
    end

    criteria ++ [order_by: {:inserted_at, :desc}]
  end
end
