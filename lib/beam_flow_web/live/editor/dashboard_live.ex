defmodule BeamFlowWeb.Editor.DashboardLive do
  use BeamFlowWeb, :live_view

  import BeamFlowWeb.DashboardComponents
  alias BeamFlow.Content

  # Apply editor role check on mount
  on_mount {BeamFlowWeb.LiveAuth, {:ensure_role, :editor}}

  @impl true
  def mount(_params, _session, socket) do
    # Get counts for dashboard cards
    post_count = length(Content.list_posts(status: "draft"))

    # In a real scenario, you'll want to have an actual comment schema and context
    comment_count = 0

    # Future: Media count when implemented
    media_count = 0

    # Get posts pending approval (draft posts)
    pending_posts = Content.list_posts(status: "draft")

    {:ok,
     socket
     |> assign(:page_title, "Editor Dashboard")
     |> assign(:post_count, post_count)
     |> assign(:comment_count, comment_count)
     |> assign(:media_count, media_count)
     |> assign(:pending_posts, pending_posts)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <.section_header
        title="Editor Dashboard"
        subtitle="Manage content, approve posts, and monitor comments"
      >
        <:actions>
          <.btn_primary navigate={~p"/editor/posts/new"}>
            <.icon name="hero-plus" class="-ml-1 mr-2 h-5 w-5" /> New Post
          </.btn_primary>
        </:actions>
      </.section_header>

      <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
        <.dashboard_card
          title="Posts"
          count={@post_count}
          icon_path="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 13a2 2 0 01-2-2V7m2 13a2 2 0 002-2V9a2 2 0 00-2-2h-2m-4-3H9M7 16h6M7 8h6v4H7V8z"
          link={~p"/editor/posts"}
          color="blue"
        />
        <.dashboard_card
          title="Comments"
          count={@comment_count}
          icon_path="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z"
          link="#"
          color="green"
        />
        <.dashboard_card
          title="Media"
          count={@media_count}
          icon_path="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
          link="#"
          color="purple"
        />
      </div>

      <div class="mt-8">
        <.section_header title="Pending Approvals" subtitle="Posts waiting for editorial review">
          <:actions>
            <%= if @post_count > 0 do %>
              <.btn_secondary navigate={~p"/editor/posts"} class="text-sm">
                View All
              </.btn_secondary>
            <% end %>
          </:actions>
        </.section_header>

        <.panel>
          <ul role="list" class="divide-y divide-gray-200">
            <%= for post <- @pending_posts do %>
              <li>
                <div class="px-4 py-4 flex items-center sm:px-6">
                  <div class="min-w-0 flex-1 sm:flex sm:items-center sm:justify-between">
                    <div>
                      <div class="flex text-sm">
                        <p class="font-medium text-indigo-600 truncate">{post.title}</p>
                        <p class="ml-1 flex-shrink-0 font-normal text-gray-500">
                          <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-gray-100 text-gray-800">
                            {post.status}
                          </span>
                        </p>
                      </div>
                      <div class="mt-2 flex">
                        <div class="flex items-center text-sm text-gray-500">
                          <p>
                            By {post.user.name}
                            <span class="mx-1">&middot;</span> Created {format_date(post.inserted_at)}
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
                        <a
                          href="#"
                          phx-click="publish"
                          phx-value-id={post.id}
                          data-confirm="Are you sure you want to publish this post?"
                          class="text-green-600 hover:text-green-900 mr-3"
                        >
                          <span>Publish</span>
                        </a>
                      </div>
                    </div>
                  </div>
                </div>
              </li>
            <% end %>

            <%= if Enum.empty?(@pending_posts) do %>
              <li>
                <div class="px-4 py-8 text-center text-gray-500">
                  No posts pending approval.
                </div>
              </li>
            <% end %>
          </ul>
        </.panel>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mt-8">
        <.panel title="Recent Comments" class="h-full">
          <div class="text-center text-gray-500 py-6">
            No recent comments to display
          </div>
        </.panel>

        <.panel title="Content Overview" class="h-full">
          <dl class="grid grid-cols-1 gap-5 sm:grid-cols-2">
            <div class="px-4 py-5 bg-gray-50 shadow rounded-lg overflow-hidden sm:p-6">
              <dt class="text-sm font-medium text-gray-500 truncate">Draft Posts</dt>
              <dd class="mt-1 text-3xl font-semibold text-gray-900">{@post_count}</dd>
            </div>
            <div class="px-4 py-5 bg-gray-50 shadow rounded-lg overflow-hidden sm:p-6">
              <dt class="text-sm font-medium text-gray-500 truncate">Published Posts</dt>
              <dd class="mt-1 text-3xl font-semibold text-gray-900">
                {length(Content.list_posts(status: "published"))}
              </dd>
            </div>
            <div class="px-4 py-5 bg-gray-50 shadow rounded-lg overflow-hidden sm:p-6">
              <dt class="text-sm font-medium text-gray-500 truncate">Comments Pending</dt>
              <dd class="mt-1 text-3xl font-semibold text-gray-900">0</dd>
            </div>
            <div class="px-4 py-5 bg-gray-50 shadow rounded-lg overflow-hidden sm:p-6">
              <dt class="text-sm font-medium text-gray-500 truncate">Media Count</dt>
              <dd class="mt-1 text-3xl font-semibold text-gray-900">{@media_count}</dd>
            </div>
          </dl>
        </.panel>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("publish", %{"id" => id}, socket) do
    post = Content.get_post!(id)

    case Content.publish_post(post) do
      {:ok, _post} ->
        {:noreply,
         socket
         |> put_flash(:info, "Post published successfully")
         |> assign(:pending_posts, Content.list_posts(status: "draft"))
         |> assign(:post_count, length(Content.list_posts(status: "draft")))}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to publish post")}
    end
  end

  # Helper function for date formatting
  defp format_date(nil), do: ""

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y %H:%M")
  end
end
