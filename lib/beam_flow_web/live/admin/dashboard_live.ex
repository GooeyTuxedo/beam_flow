defmodule BeamFlowWeb.Admin.DashboardLive do
  use BeamFlowWeb, :live_view

  alias BeamFlow.Content

  @impl true
  def mount(_params, _session, socket) do
    post_count = length(Content.list_posts())

    {:ok,
     socket
     |> assign(:page_title, "Admin Dashboard")
     |> assign(:post_count, post_count)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div class="mb-8 sm:flex sm:items-center sm:justify-between">
        <div class="mb-4 sm:mb-0">
          <h1 class="text-3xl font-bold text-gray-900">Admin Dashboard</h1>
          <p class="mt-1 text-sm text-gray-500">Manage your blog content and users</p>
        </div>
        <div>
          <span class="inline-flex rounded-md shadow-sm">
            <.link
              navigate={~p"/admin/users/new"}
              class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
            >
              <svg
                class="-ml-1 mr-2 h-5 w-5"
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 6v6m0 0v6m0-6h6m-6 0H6"
                />
              </svg>
              New User
            </.link>
          </span>
        </div>
      </div>

      <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
        <.dashboard_card
          title="Users"
          count={0}
          icon_path="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"
          link={~p"/admin/users"}
        />
        <.dashboard_card
          title="Posts"
          count={@post_count}
          icon_path="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 13a2 2 0 01-2-2V7m2 13a2 2 0 002-2V9a2 2 0 00-2-2h-2m-4-3H9M7 16h6M7 8h6v4H7V8z"
          link={~p"/admin/posts"}
        />
        <.dashboard_card
          title="Comments"
          count={0}
          icon_path="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z"
          link="#"
        />
      </div>

      <div class="mt-8">
        <h2 class="text-xl font-semibold text-gray-900 mb-4">Recent Activity</h2>
        <div class="bg-white shadow overflow-hidden sm:rounded-md">
          <div class="px-4 py-5 sm:p-6 text-center text-gray-500">
            No recent activity to display
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp dashboard_card(assigns) do
    ~H"""
    <div class="bg-white overflow-hidden shadow rounded-lg" data-test-id="dashboard-card">
      <div class="p-5">
        <div class="flex items-center">
          <div class="flex-shrink-0 bg-indigo-500 rounded-md p-3">
            <svg
              class="h-6 w-6 text-white"
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d={@icon_path} />
            </svg>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">
                {@title}
              </dt>
              <dd>
                <div class="text-lg font-medium text-gray-900">
                  {@count}
                </div>
              </dd>
            </dl>
          </div>
        </div>
      </div>
      <div class="bg-gray-50 px-5 py-3">
        <div class="text-sm">
          <.link navigate={@link} class="font-medium text-indigo-600 hover:text-indigo-500">
            View all
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
