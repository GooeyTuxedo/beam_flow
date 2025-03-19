defmodule BeamFlowWeb.Editor.PostLive.Index do
  use BeamFlowWeb, :live_view

  import BeamFlowWeb.DashboardComponents
  alias BeamFlow.Content
  alias BeamFlow.Content.Post

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

    # Editors can delete any post
    {:ok, _post} = Content.delete_post(post)

    {:noreply,
     socket
     |> put_flash(:info, "Post deleted successfully")
     |> assign_posts()}
  end

  @impl true
  def handle_event("publish", %{"id" => id}, socket) do
    post = Content.get_post!(id)

    # Editors can publish any post
    {:ok, _post} = Content.publish_post(post)

    {:noreply,
     socket
     |> put_flash(:info, "Post published successfully")
     |> assign_posts()}
  end

  @impl true
  def handle_event("filter", %{"filter" => filter}, socket) do
    {:noreply,
     socket
     |> assign(:filter, filter)
     |> assign_posts()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <.section_header title="Posts" subtitle="Manage and review all blog content">
        <:actions>
          <.btn_primary patch={~p"/editor/posts/new"}>
            <.icon name="hero-plus" class="w-5 h-5 mr-2" /> New Post
          </.btn_primary>
        </:actions>
      </.section_header>

      <.panel title="Filter Posts" class="mb-8">
        <form phx-change="filter">
          <div class="grid grid-cols-1 gap-y-6 gap-x-4 sm:grid-cols-6">
            <div class="sm:col-span-2">
              <label for="filter_status" class="block text-sm font-medium text-gray-700">
                Status
              </label>
              <select
                id="filter_status"
                name="filter[status]"
                class="mt-1 block w-full py-2 px-3 border border-gray-300 bg-white rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
              >
                <option value="">All</option>
                <option value="draft" selected={@filter["status"] == "draft"}>Draft</option>
                <option value="published" selected={@filter["status"] == "published"}>
                  Published
                </option>
                <option value="scheduled" selected={@filter["status"] == "scheduled"}>
                  Scheduled
                </option>
              </select>
            </div>

            <div class="sm:col-span-4">
              <label for="filter_search" class="block text-sm font-medium text-gray-700">
                Search
              </label>
              <div class="mt-1 flex rounded-md shadow-sm">
                <input
                  type="text"
                  name="filter[search]"
                  id="filter_search"
                  value={@filter["search"]}
                  class="flex-1 focus:ring-indigo-500 focus:border-indigo-500 block w-full min-w-0 rounded-md sm:text-sm border-gray-300"
                  placeholder="Search by title or content"
                />
              </div>
            </div>
          </div>
        </form>
      </.panel>

      <.panel>
        <ul role="list" class="divide-y divide-gray-200">
          <%= for post <- @posts do %>
            <li>
              <div class="px-4 py-4 flex items-center sm:px-6">
                <div class="min-w-0 flex-1 sm:flex sm:items-center sm:justify-between">
                  <div>
                    <div class="flex text-sm">
                      <p class="font-medium text-indigo-600 truncate">{post.title}</p>
                      <p class="ml-1 flex-shrink-0 font-normal text-gray-500">
                        <span class={[
                          "px-2 inline-flex text-xs leading-5 font-semibold rounded-full",
                          status_badge_color(post.status)
                        ]}>
                          {post.status}
                        </span>
                      </p>
                    </div>
                    <div class="mt-2 flex">
                      <div class="flex items-center text-sm text-gray-500">
                        <p>
                          By {post.user.name}
                          <span class="mx-1">&middot;</span>
                          Created {format_date(post.inserted_at)}
                          <%= if post.published_at do %>
                            <span class="mx-1">&middot;</span>
                            Published {format_date(post.published_at)}
                          <% end %>
                        </p>
                      </div>
                    </div>
                  </div>
                  <div class="mt-4 flex-shrink-0 sm:mt-0 sm:ml-5">
                    <div class="flex overflow-hidden">
                      <.link
                        patch={~p"/editor/posts/#{post.id}/edit"}
                        class="text-indigo-600 hover:text-indigo-900 mr-3"
                      >
                        <span>Edit</span>
                      </.link>

                      <%= if post.status == "draft" do %>
                        <a
                          href="#"
                          phx-click="publish"
                          phx-value-id={post.id}
                          data-confirm="Are you sure you want to publish this post?"
                          class="text-green-600 hover:text-green-900 mr-3"
                        >
                          <span>Publish</span>
                        </a>
                      <% end %>

                      <a
                        href="#"
                        phx-click="delete"
                        phx-value-id={post.id}
                        data-confirm="Are you sure you want to delete this post?"
                        class="text-red-600 hover:text-red-900"
                      >
                        <span>Delete</span>
                      </a>
                    </div>
                  </div>
                </div>
              </div>
            </li>
          <% end %>

          <%= if Enum.empty?(@posts) do %>
            <li>
              <div class="px-4 py-8 text-center text-gray-500">
                No posts found.
                <%= if @filter["status"] || @filter["search"] do %>
                  Try adjusting your filters.
                <% end %>
              </div>
            </li>
          <% end %>
        </ul>
      </.panel>
    </div>

    <%= if @live_action in [:new, :edit] do %>
      <.modal id="post-modal" show on_cancel={JS.patch(~p"/editor/posts")}>
        <.live_component
          module={BeamFlowWeb.Admin.PostLive.FormComponent}
          id={@post.id || :new}
          title={@page_title}
          action={@live_action}
          post={@post}
          current_user={@current_user}
          return_to={~p"/editor/posts"}
        />
      </.modal>
    <% end %>
    """
  end

  defp assign_posts(socket) do
    socket = BeamFlowWeb.LiveAuth.assign_user_roles(socket)

    filter = socket.assigns.filter
    criteria = build_criteria(filter)
    assign(socket, :posts, Content.list_posts(criteria))
  end

  defp build_criteria(filter) do
    criteria = []

    criteria =
      if filter["status"] && filter["status"] != "",
        do: [{:status, filter["status"]} | criteria],
        else: criteria

    criteria =
      if filter["search"] && filter["search"] != "",
        do: [{:search, filter["search"]} | criteria],
        else: criteria

    # Editors can see all posts
    criteria ++ [order_by: {:inserted_at, :desc}]
  end

  # Helper functions

  defp status_badge_color("draft"), do: "bg-gray-100 text-gray-800"
  defp status_badge_color("published"), do: "bg-green-100 text-green-800"
  defp status_badge_color("scheduled"), do: "bg-blue-100 text-blue-800"
  defp status_badge_color(_else), do: "bg-gray-100 text-gray-800"

  defp format_date(nil), do: ""

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y %H:%M")
  end
end
