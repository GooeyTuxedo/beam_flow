defmodule BeamFlowWeb.Admin.UserLive.Index do
  use BeamFlowWeb, :live_view

  alias BeamFlow.Accounts
  alias BeamFlow.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       users: list_users(),
       page_title: "Users"
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Users")
    |> assign(:user, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New User")
    |> assign(:user, %User{})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit User")
    |> assign(:user, Accounts.get_user!(id))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Users</h1>
        <span>
          <.link
            navigate={~p"/admin/users/new"}
            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700"
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

      <div class="bg-white shadow overflow-hidden sm:rounded-lg">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th
                scope="col"
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
              >
                Name
              </th>
              <th
                scope="col"
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
              >
                Email
              </th>
              <th
                scope="col"
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
              >
                Role
              </th>
              <th
                scope="col"
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
              >
                Status
              </th>
              <th scope="col" class="relative px-6 py-3">
                <span class="sr-only">Actions</span>
              </th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <%= for user <- @users do %>
              <tr id={"user-#{user.id}"}>
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="flex items-center">
                    <div class="h-10 w-10 flex-shrink-0">
                      <div class="h-10 w-10 rounded-full bg-gray-200 flex items-center justify-center">
                        <span class="text-gray-600 font-medium">{String.first(user.name)}</span>
                      </div>
                    </div>
                    <div class="ml-4">
                      <div class="text-sm font-medium text-gray-900">{user.name}</div>
                    </div>
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="text-sm text-gray-900">{user.email}</div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class={[
                    "px-2 inline-flex text-xs leading-5 font-semibold rounded-full",
                    role_badge_color(user.role)
                  ]}>
                    {String.capitalize(to_string(user.role))}
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class={[
                    "px-2 inline-flex text-xs leading-5 font-semibold rounded-full",
                    if(user.confirmed_at,
                      do: "bg-green-100 text-green-800",
                      else: "bg-yellow-100 text-yellow-800"
                    )
                  ]}>
                    {if user.confirmed_at, do: "Confirmed", else: "Unconfirmed"}
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <.link
                    navigate={~p"/admin/users/#{user}/edit"}
                    class="text-indigo-600 hover:text-indigo-900 mr-4"
                  >
                    Edit
                  </.link>
                  <.link
                    href="#"
                    phx-click="delete"
                    phx-value-id={user.id}
                    data-confirm="Are you sure?"
                    class="text-red-600 hover:text-red-900"
                  >
                    Delete
                  </.link>
                </td>
              </tr>
            <% end %>
            <%= if Enum.empty?(@users) do %>
              <tr>
                <td colspan="5" class="px-6 py-4 whitespace-nowrap text-center text-gray-500">
                  No users found
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <div class="mt-6">
        <.link navigate={~p"/admin"} class="text-indigo-600 hover:text-indigo-900">
          &larr; Back to dashboard
        </.link>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    current_user = socket.assigns.current_user

    if user.id != current_user.id do
      # For now, we'll just show a flash message instead of actually deleting
      # In a real implementation, you would call Accounts.delete_user(user)
      {:noreply,
       socket
       |> put_flash(:info, "User deletion would happen here (disabled for demo)")
       |> push_navigate(to: ~p"/admin/users")}
    else
      {:noreply,
       socket
       |> put_flash(:error, "You cannot delete your own account")
       |> push_navigate(to: ~p"/admin/users")}
    end
  end

  defp list_users do
    Accounts.list_users()
  end

  defp role_badge_color(role) do
    case role do
      :admin -> "bg-purple-100 text-purple-800"
      :editor -> "bg-blue-100 text-blue-800"
      :author -> "bg-green-100 text-green-800"
      :subscriber -> "bg-gray-100 text-gray-800"
      _nonexistant_role -> "bg-gray-100 text-gray-800"
    end
  end
end
