defmodule BeamFlowWeb.Author.DashboardLive do
  use BeamFlowWeb, :live_view

  import BeamFlowWeb.DashboardComponents
  alias BeamFlow.Content

  # Apply author role check on mount
  on_mount {BeamFlowWeb.LiveAuth, {:ensure_role, :author}}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    # Filter posts by the current user
    my_posts = Content.list_posts(user_id: current_user.id)

    # Filter draft posts by the current user
    my_drafts = Content.list_posts(user_id: current_user.id, status: "draft")

    # Get post counts for dashboard cards
    my_posts_count = length(my_posts)
    my_drafts_count = length(my_drafts)

    # In a real scenario, you'd have comments related to the author's posts
    my_comments_count = 0

    # Get the author's most recent posts
    recent_posts = my_posts |> Enum.take(5)

    {:ok,
     socket
     |> assign(:page_title, "Author Dashboard")
     |> assign(:my_posts_count, my_posts_count)
     |> assign(:my_drafts_count, my_drafts_count)
     |> assign(:my_comments_count, my_comments_count)
     |> assign(:recent_posts, recent_posts)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <.section_header title="Author Dashboard" subtitle="Create and manage your content">
        <:actions>
          <.btn_primary navigate={~p"/author/posts/new"}>
            <.icon name="hero-plus" class="-ml-1 mr-2 h-5 w-5" /> New Post
          </.btn_primary>
        </:actions>
      </.section_header>

      <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
        <.dashboard_card
          title="My Posts"
          count={@my_posts_count}
          icon_path="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 13a2 2 0 01-2-2V7m2 13a2 2 0 002-2V9a2 2 0 00-2-2h-2m-4-3H9M7 16h6M7 8h6v4H7V8z"
          link={~p"/author/posts"}
          color="blue"
        />
        <.dashboard_card
          title="Drafts"
          count={@my_drafts_count}
          icon_path="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
          link={~p"/author/posts"}
          color="yellow"
        />
        <.dashboard_card
          title="Comments"
          count={@my_comments_count}
          icon_path="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z"
          link="#"
          color="green"
        />
      </div>

      <div class="mt-8">
        <.section_header title="Recent Posts" subtitle="Your latest content">
          <:actions>
            <%= if @my_posts_count > 0 do %>
              <.btn_secondary navigate={~p"/author/posts"} class="text-sm">
                View All
              </.btn_secondary>
            <% end %>
          </:actions>
        </.section_header>

        <.panel>
          <ul role="list" class="divide-y divide-gray-200">
            <%= for post <- @recent_posts do %>
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
                          patch={~p"/author/posts/#{post.id}/edit"}
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

            <%= if Enum.empty?(@recent_posts) do %>
              <li>
                <div class="px-4 py-8 text-center text-gray-500">
                  You haven't created any posts yet. Click "New Post" to get started.
                </div>
              </li>
            <% end %>
          </ul>
        </.panel>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mt-8">
        <.panel title="Content Performance" class="h-full">
          <div class="text-center text-gray-500 py-6">
            Content performance metrics will be available once analytics are implemented.
          </div>
        </.panel>

        <.panel title="Writing Tips" class="h-full">
          <ul class="space-y-4 text-sm">
            <li class="flex">
              <.icon name="hero-light-bulb" class="h-5 w-5 text-yellow-500 mr-2" />
              <span>Use descriptive titles that include keywords relevant to your content.</span>
            </li>
            <li class="flex">
              <.icon name="hero-light-bulb" class="h-5 w-5 text-yellow-500 mr-2" />
              <span>Write a compelling excerpt to encourage readers to click through.</span>
            </li>
            <li class="flex">
              <.icon name="hero-light-bulb" class="h-5 w-5 text-yellow-500 mr-2" />
              <span>
                Break up long content with headings, lists, and images for better readability.
              </span>
            </li>
            <li class="flex">
              <.icon name="hero-light-bulb" class="h-5 w-5 text-yellow-500 mr-2" />
              <span>Use categories and tags to help readers discover related content.</span>
            </li>
            <li class="flex">
              <.icon name="hero-light-bulb" class="h-5 w-5 text-yellow-500 mr-2" />
              <span>Proofread your content before publishing to catch any errors.</span>
            </li>
          </ul>
        </.panel>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("publish", %{"id" => id}, socket) do
    post = Content.get_post!(id)
    current_user = socket.assigns.current_user

    # Check that the post belongs to the current user
    if post.user_id == current_user.id do
      case Content.publish_post(post) do
        {:ok, _post} ->
          # Refresh the post lists
          my_posts = Content.list_posts(user_id: current_user.id)
          my_drafts = Content.list_posts(user_id: current_user.id, status: "draft")

          {:noreply,
           socket
           |> put_flash(:info, "Post published successfully")
           |> assign(:recent_posts, my_posts |> Enum.take(5))
           |> assign(:my_posts_count, length(my_posts))
           |> assign(:my_drafts_count, length(my_drafts))}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to publish post")}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "You can only publish your own posts")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    post = Content.get_post!(id)
    current_user = socket.assigns.current_user

    # Check that the post belongs to the current user
    if post.user_id == current_user.id do
      case Content.delete_post(post) do
        {:ok, _changeset} ->
          # Refresh the post lists
          my_posts = Content.list_posts(user_id: current_user.id)
          my_drafts = Content.list_posts(user_id: current_user.id, status: "draft")

          {:noreply,
           socket
           |> put_flash(:info, "Post deleted successfully")
           |> assign(:recent_posts, my_posts |> Enum.take(5))
           |> assign(:my_posts_count, length(my_posts))
           |> assign(:my_drafts_count, length(my_drafts))}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to delete post")}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "You can only delete your own posts")}
    end
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
