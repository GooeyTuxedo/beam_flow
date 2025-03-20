defmodule BeamFlowWeb.Author.DashboardLive do
  use BeamFlowWeb, :live_view

  import BeamFlowWeb.DashboardComponents
  alias BeamFlow.Accounts
  alias BeamFlow.Content

  # Apply author role check on mount
  on_mount {BeamFlowWeb.LiveAuth, {:ensure_role, :author}}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    # Filter posts by the current user
    my_posts = Content.list_posts(user_id: current_user.id)
    my_posts_count = length(my_posts)

    # Filter by status
    my_drafts = Content.list_posts(user_id: current_user.id, status: "draft")
    my_drafts_count = length(my_drafts)

    my_published = Content.list_posts(user_id: current_user.id, status: "published")
    my_published_count = length(my_published)

    # In a real scenario, you'd have comments related to the author's posts
    my_comments_count = 0

    # Get the author's most recent posts and drafts
    recent_posts = my_posts |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime}) |> Enum.take(5)
    recent_drafts = my_drafts |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime}) |> Enum.take(5)

    # Get the author's recent activities
    recent_activities = Accounts.list_user_logs(current_user.id, 5)

    {:ok,
     socket
     |> assign(:page_title, "Author Dashboard")
     |> assign(:my_posts_count, my_posts_count)
     |> assign(:my_drafts_count, my_drafts_count)
     |> assign(:my_published_count, my_published_count)
     |> assign(:my_comments_count, my_comments_count)
     |> assign(:recent_posts, recent_posts)
     |> assign(:recent_drafts, recent_drafts)
     |> assign(:recent_activities, recent_activities)}
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

      <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
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
          link={~p"/author/posts?status=draft"}
          color="yellow"
        />
        <.dashboard_card
          title="Published"
          count={@my_published_count}
          icon_path="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z"
          link={~p"/author/posts?status=published"}
          color="green"
        />
        <.dashboard_card
          title="Comments"
          count={@my_comments_count}
          icon_path="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z"
          link="#"
          color="purple"
        />
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mt-8">
        <.panel title="Recent Posts" class="h-full">
          <ul class="divide-y divide-gray-200">
            <%= for post <- @recent_posts do %>
              <li class="py-4">
                <div class="flex space-x-3">
                  <div class="flex-1 space-y-1">
                    <div class="flex items-center justify-between">
                      <h3 class="text-sm font-medium">
                        <.link
                          navigate={~p"/author/posts/#{post.id}/edit"}
                          class="text-indigo-600 hover:text-indigo-900"
                        >
                          {post.title}
                        </.link>
                      </h3>
                      <.status_badge status={post.status} />
                    </div>
                    <p class="text-sm text-gray-500">
                      Created {format_date(post.inserted_at)}
                      <%= if post.published_at do %>
                        • Published {format_date(post.published_at)}
                      <% end %>
                    </p>
                    <div class="mt-2 flex">
                      <.link
                        navigate={~p"/author/posts/#{post.id}/edit"}
                        class="inline-flex items-center px-2.5 py-1.5 border border-gray-300 shadow-sm text-xs font-medium rounded text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                      >
                        Edit
                      </.link>
                      <%= if post.status == "draft" do %>
                        <button
                          phx-click="publish"
                          phx-value-id={post.id}
                          class="ml-3 inline-flex items-center px-2.5 py-1.5 border border-transparent text-xs font-medium rounded text-indigo-700 bg-indigo-100 hover:bg-indigo-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                        >
                          Publish
                        </button>
                      <% end %>
                    </div>
                  </div>
                </div>
              </li>
            <% end %>
            <%= if Enum.empty?(@recent_posts) do %>
              <li class="py-4 text-center text-gray-500">
                You haven't created any posts yet. Click "New Post" to get started.
              </li>
            <% end %>
          </ul>
        </.panel>

        <.panel title="My Drafts" class="h-full">
          <ul class="divide-y divide-gray-200">
            <%= for post <- @recent_drafts do %>
              <li class="py-4">
                <div class="flex space-x-3">
                  <div class="flex-1 space-y-1">
                    <div class="flex items-center justify-between">
                      <h3 class="text-sm font-medium">
                        <.link
                          navigate={~p"/author/posts/#{post.id}/edit"}
                          class="text-indigo-600 hover:text-indigo-900"
                        >
                          {post.title}
                        </.link>
                      </h3>
                      <.status_badge status={post.status} />
                    </div>
                    <p class="text-sm text-gray-500">
                      Last updated {format_date(post.updated_at || post.inserted_at)}
                    </p>
                    <div class="mt-2 flex">
                      <.link
                        navigate={~p"/author/posts/#{post.id}/edit"}
                        class="inline-flex items-center px-2.5 py-1.5 border border-gray-300 shadow-sm text-xs font-medium rounded text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                      >
                        Edit
                      </.link>
                      <button
                        phx-click="publish"
                        phx-value-id={post.id}
                        class="ml-3 inline-flex items-center px-2.5 py-1.5 border border-transparent text-xs font-medium rounded text-indigo-700 bg-indigo-100 hover:bg-indigo-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                      >
                        Publish
                      </button>
                    </div>
                  </div>
                </div>
              </li>
            <% end %>
            <%= if Enum.empty?(@recent_drafts) do %>
              <li class="py-4 text-center text-gray-500">
                You don't have any drafts. Create a new post to get started!
              </li>
            <% end %>
          </ul>
        </.panel>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mt-8">
        <.panel title="Writing Tips" class="h-full">
          <ul class="space-y-4 text-sm">
            <li class="flex">
              <.icon name="hero-light-bulb" class="h-5 w-5 text-yellow-500 mr-2 flex-shrink-0" />
              <span>Use descriptive titles that include keywords relevant to your content.</span>
            </li>
            <li class="flex">
              <.icon name="hero-light-bulb" class="h-5 w-5 text-yellow-500 mr-2 flex-shrink-0" />
              <span>Write a compelling excerpt to encourage readers to click through.</span>
            </li>
            <li class="flex">
              <.icon name="hero-light-bulb" class="h-5 w-5 text-yellow-500 mr-2 flex-shrink-0" />
              <span>
                Break up long content with headings, lists, and images for better readability.
              </span>
            </li>
            <li class="flex">
              <.icon name="hero-light-bulb" class="h-5 w-5 text-yellow-500 mr-2 flex-shrink-0" />
              <span>Use categories and tags to help readers discover related content.</span>
            </li>
            <li class="flex">
              <.icon name="hero-light-bulb" class="h-5 w-5 text-yellow-500 mr-2 flex-shrink-0" />
              <span>Proofread your content before publishing to catch any errors.</span>
            </li>
          </ul>
        </.panel>

        <.panel title="Recent Activity" class="h-full">
          <div class="flow-root">
            <ul class="-mb-8">
              <%= for activity <- @recent_activities do %>
                <li>
                  <.activity_log_item
                    user={%{name: "You"}}
                    action={activity.action}
                    resource_type={activity.resource_type}
                    resource_id={activity.resource_id}
                    timestamp={activity.inserted_at}
                    details={activity.metadata["path"]}
                  />
                </li>
              <% end %>
              <%= if Enum.empty?(@recent_activities) do %>
                <li class="py-4 text-center text-gray-500">
                  No recent activity to display
                </li>
              <% end %>
            </ul>
          </div>
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
          my_published = Content.list_posts(user_id: current_user.id, status: "published")

          recent_posts =
            my_posts
            |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
            |> Enum.take(5)

          recent_drafts =
            my_drafts
            |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
            |> Enum.take(5)

          {:noreply,
           socket
           |> put_flash(:info, "Post published successfully")
           |> assign(:recent_posts, recent_posts)
           |> assign(:recent_drafts, recent_drafts)
           |> assign(:my_posts_count, length(my_posts))
           |> assign(:my_drafts_count, length(my_drafts))
           |> assign(:my_published_count, length(my_published))}

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

  # Helper functions
  defp format_date(nil), do: ""

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y %H:%M")
  end
end
