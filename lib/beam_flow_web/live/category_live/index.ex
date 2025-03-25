defmodule BeamFlowWeb.CategoryLive.Index do
  use BeamFlowWeb, :live_view
  alias BeamFlow.Accounts.Auth
  alias BeamFlow.Content
  alias BeamFlow.Content.Category

  on_mount {BeamFlowWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    if Auth.can?(socket.assigns.current_user, :read, {:category, nil}) do
      categories = Content.list_categories()
      {:ok, assign(socket, :categories, categories)}
    else
      # Redirect to role-appropriate dashboard based on user role
      role_path = role_base_path(socket.assigns.current_user.role)
      {:ok, push_navigate(socket, to: role_path)}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    # Reload categories when returning to index
    categories = Content.list_categories()

    socket
    |> assign(:categories, categories)
    |> assign(:page_title, "Categories")
    |> assign(:category, nil)
  end

  defp apply_action(socket, :new, _params) do
    if Auth.can?(socket.assigns.current_user, :create, {:category, nil}) do
      socket
      |> assign(:page_title, "New Category")
      |> assign(:category, %Category{})
    else
      role_path = "#{role_base_path(socket.assigns.current_user.role)}/categories"

      socket
      |> put_flash(:error, "Not authorized")
      |> push_navigate(to: role_path)
    end
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    category = Content.get_category!(id)

    if Auth.can?(socket.assigns.current_user, :update, {:category, category}) do
      socket
      |> assign(:page_title, "Edit Category")
      |> assign(:category, category)
    else
      role_path = "#{role_base_path(socket.assigns.current_user.role)}/categories"

      socket
      |> put_flash(:error, "Not authorized")
      |> push_navigate(to: role_path)
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    category = Content.get_category!(id)

    if Auth.can?(socket.assigns.current_user, :delete, {:category, category}) do
      {:ok, _foo} = Content.delete_category(category)

      {:noreply,
       socket
       |> put_flash(:info, "Category deleted successfully")
       |> assign(categories: Content.list_categories())}
    else
      role_path = "#{role_base_path(socket.assigns.current_user.role)}/categories"

      {:noreply,
       socket
       |> put_flash(:error, "Not authorized")
       |> push_navigate(to: role_path)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <.header>
        Categories
        <:actions>
          <%= if Auth.can?(@current_user, :create, {:category, nil}) do %>
            <.link patch={"#{role_base_path(@current_user.role)}/categories/new"}>
              <.button>New Category</.button>
            </.link>
          <% end %>
        </:actions>
      </.header>

      <.table id="categories" rows={@categories}>
        <:col :let={category} label="Name">{category.name}</:col>
        <:col :let={category} label="Slug">{category.slug}</:col>
        <:col :let={category} label="Description">{category.description}</:col>
        <:action :let={category}>
          <%= if Auth.can?(@current_user, :update, {:category, category}) do %>
            <.link patch={"#{role_base_path(@current_user.role)}/categories/#{category.id}/edit"}>
              Edit
            </.link>
          <% end %>
        </:action>
        <:action :let={category}>
          <%= if Auth.can?(@current_user, :delete, {:category, category}) do %>
            <.link
              phx-click={JS.push("delete", value: %{id: category.id}) |> hide("##{category.id}")}
              data-confirm="Are you sure?"
            >
              Delete
            </.link>
          <% end %>
        </:action>
      </.table>

      <%= if @live_action in [:new, :edit] do %>
        <.modal
          id="category-modal"
          show
          on_cancel={JS.patch("#{role_base_path(@current_user.role)}/categories")}
        >
          <.live_component
            module={BeamFlowWeb.CategoryLive.FormComponent}
            id={@category.id || :new}
            title={@page_title}
            action={@live_action}
            category={@category}
            current_user={@current_user}
            navigate={"#{role_base_path(@current_user.role)}/categories"}
          />
        </.modal>
      <% end %>
    </div>
    """
  end

  # Helper function to get the base path based on user role
  defp role_base_path(role) do
    case role do
      :admin -> ~p"/admin"
      :editor -> ~p"/editor"
      :author -> ~p"/author"
      _other -> ~p"/"
    end
  end
end
