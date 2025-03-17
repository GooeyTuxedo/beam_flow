defmodule BeamFlowWeb.Editor.DashboardLive do
  use BeamFlowWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Editor Dashboard")}
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
          <h1 class="text-3xl font-bold text-gray-900">Editor Dashboard</h1>
          <p class="mt-1 text-sm text-gray-500">Manage content and review submissions</p>
        </div>
      </div>

      <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
        <.dashboard_card
          title="Posts"
          count={0}
          icon_path="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 13a2 2 0 01-2-2V7m2 13a2 2 0 002-2V9a2 2 0 00-2-2h-2m-4-3H9M7 16h6M7 8h6v4H7V8z"
          link="#"
        />
        <.dashboard_card
          title="Comments"
          count={0}
          icon_path="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z"
          link="#"
        />
        <.dashboard_card
          title="Media"
          count={0}
          icon_path="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
          link="#"
        />
      </div>

      <div class="mt-8">
        <h2 class="text-xl font-semibold text-gray-900 mb-4">Pending Approvals</h2>
        <div class="bg-white shadow overflow-hidden sm:rounded-md">
          <div class="px-4 py-5 sm:p-6 text-center text-gray-500">
            No pending approvals to display
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
          <div class="flex-shrink-0 bg-blue-500 rounded-md p-3">
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
          <.link navigate={@link} class="font-medium text-blue-600 hover:text-blue-500">
            View all
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
