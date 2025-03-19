defmodule BeamFlowWeb.Admin.DashboardLive do
  use BeamFlowWeb, :live_view

  import BeamFlowWeb.AdminComponents
  alias BeamFlow.Accounts
  alias BeamFlow.Content

  # Apply admin role check on mount
  on_mount {BeamFlowWeb.LiveAuth, {:ensure_role, :admin}}

  @impl true
  def mount(_params, _session, socket) do
    # Get counts for dashboard cards
    post_count = length(Content.list_posts())
    user_count = length(Accounts.list_users())

    # You could add more metrics here as needed
    comment_count = 0

    # Get recent activity (could be audit logs or recent content)
    # Implementation will depend on your needs
    recent_activities = []

    {:ok,
     socket
     |> assign(:page_title, "Admin Dashboard")
     |> assign(:post_count, post_count)
     |> assign(:user_count, user_count)
     |> assign(:comment_count, comment_count)
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
      <.section_header title="Dashboard" subtitle="Manage your blog content and users">
        <:actions>
          <.btn_primary navigate={~p"/admin/users/new"} class="mr-3">
            <.icon name="hero-plus" class="-ml-1 mr-2 h-5 w-5" /> New User
          </.btn_primary>

          <.btn_primary navigate={~p"/admin/posts/new"}>
            <.icon name="hero-plus" class="-ml-1 mr-2 h-5 w-5" /> New Post
          </.btn_primary>
        </:actions>
      </.section_header>

      <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
        <.dashboard_card
          title="Users"
          count={@user_count}
          icon_path="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"
          link={~p"/admin/users"}
          color="purple"
        />
        <.dashboard_card
          title="Posts"
          count={@post_count}
          icon_path="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 13a2 2 0 01-2-2V7m2 13a2 2 0 002-2V9a2 2 0 00-2-2h-2m-4-3H9M7 16h6M7 8h6v4H7V8z"
          link={~p"/admin/posts"}
          color="blue"
        />
        <.dashboard_card
          title="Comments"
          count={@comment_count}
          icon_path="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z"
          link="#"
          color="green"
        />
      </div>

      <div class="mt-8">
        <.panel title="Recent Activity" class="mt-6">
          <div class="text-center text-gray-500 py-6">
            No recent activity to display
          </div>
        </.panel>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mt-8">
        <.panel title="Quick Stats" class="h-full">
          <dl class="grid grid-cols-1 gap-5 sm:grid-cols-2">
            <div class="px-4 py-5 bg-gray-50 shadow rounded-lg overflow-hidden sm:p-6">
              <dt class="text-sm font-medium text-gray-500 truncate">Draft Posts</dt>
              <dd class="mt-1 text-3xl font-semibold text-gray-900">0</dd>
            </div>
            <div class="px-4 py-5 bg-gray-50 shadow rounded-lg overflow-hidden sm:p-6">
              <dt class="text-sm font-medium text-gray-500 truncate">Published Posts</dt>
              <dd class="mt-1 text-3xl font-semibold text-gray-900">0</dd>
            </div>
            <div class="px-4 py-5 bg-gray-50 shadow rounded-lg overflow-hidden sm:p-6">
              <dt class="text-sm font-medium text-gray-500 truncate">Total Views</dt>
              <dd class="mt-1 text-3xl font-semibold text-gray-900">0</dd>
            </div>
            <div class="px-4 py-5 bg-gray-50 shadow rounded-lg overflow-hidden sm:p-6">
              <dt class="text-sm font-medium text-gray-500 truncate">Comments Pending</dt>
              <dd class="mt-1 text-3xl font-semibold text-gray-900">0</dd>
            </div>
          </dl>
        </.panel>

        <.panel title="System Information" class="h-full">
          <div class="space-y-4">
            <div>
              <h4 class="text-sm font-medium text-gray-500">Phoenix Version</h4>
              <p class="mt-1 text-md text-gray-900">1.7.x</p>
            </div>
            <div>
              <h4 class="text-sm font-medium text-gray-500">Elixir Version</h4>
              <p class="mt-1 text-md text-gray-900">1.15.x</p>
            </div>
            <div>
              <h4 class="text-sm font-medium text-gray-500">Database Status</h4>
              <p class="mt-1 text-md text-gray-900">
                <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800">
                  Connected
                </span>
              </p>
            </div>
            <div>
              <h4 class="text-sm font-medium text-gray-500">System Status</h4>
              <p class="mt-1 text-md text-gray-900">
                <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800">
                  Healthy
                </span>
              </p>
            </div>
          </div>
        </.panel>
      </div>
    </div>
    """
  end
end
