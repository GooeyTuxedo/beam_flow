defmodule BeamFlowWeb.TagLive.Index do
  use BeamFlowWeb, :live_view
  alias BeamFlow.Accounts.Auth
  alias BeamFlow.Content
  alias BeamFlow.Content.Tag

  on_mount {BeamFlowWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    if Auth.can?(socket.assigns.current_user, :read, {:tag, nil}) do
      tags = Content.list_tags()
      {:ok, assign(socket, :tags, tags)}
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
    # Reload tags when returning to index
    tags = Content.list_tags()

    socket
    |> assign(:tags, tags)
    |> assign(:page_title, "Tags")
    |> assign(:tag, nil)
  end

  defp apply_action(socket, :new, _params) do
    if Auth.can?(socket.assigns.current_user, :create, {:tag, nil}) do
      socket
      |> assign(:page_title, "New Tag")
      |> assign(:tag, %Tag{})
    else
      role_path = "#{role_base_path(socket.assigns.current_user.role)}/tags"

      socket
      |> put_flash(:error, "Not authorized")
      |> push_navigate(to: role_path)
    end
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    tag = Content.get_tag!(id)

    if Auth.can?(socket.assigns.current_user, :update, {:tag, tag}) do
      socket
      |> assign(:page_title, "Edit Tag")
      |> assign(:tag, tag)
    else
      role_path = "#{role_base_path(socket.assigns.current_user.role)}/tags"

      socket
      |> put_flash(:error, "Not authorized")
      |> push_navigate(to: role_path)
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    tag = Content.get_tag!(id)

    if Auth.can?(socket.assigns.current_user, :delete, {:tag, tag}) do
      {:ok, _foo} = Content.delete_tag(tag)

      {:noreply,
       socket
       |> put_flash(:info, "Tag deleted successfully")
       |> assign(tags: Content.list_tags())}
    else
      role_path = "#{role_base_path(socket.assigns.current_user.role)}/tags"

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
        Tags
        <:actions>
          <%= if Auth.can?(@current_user, :create, {:tag, nil}) do %>
            <.link patch={"#{role_base_path(@current_user.role)}/tags/new"}>
              <.button>New Tag</.button>
            </.link>
          <% end %>
        </:actions>
      </.header>

      <.table id="tags" rows={@tags}>
        <:col :let={tag} label="Name">{tag.name}</:col>
        <:col :let={tag} label="Slug">{tag.slug}</:col>
        <:action :let={tag}>
          <%= if Auth.can?(@current_user, :update, {:tag, tag}) do %>
            <.link patch={"#{role_base_path(@current_user.role)}/tags/#{tag.id}/edit"}>Edit</.link>
          <% end %>
        </:action>
        <:action :let={tag}>
          <%= if Auth.can?(@current_user, :delete, {:tag, tag}) do %>
            <.link
              phx-click={JS.push("delete", value: %{id: tag.id}) |> hide("##{tag.id}")}
              data-confirm="Are you sure?"
            >
              Delete
            </.link>
          <% end %>
        </:action>
      </.table>

      <%= if @live_action in [:new, :edit] do %>
        <.modal id="tag-modal" show on_cancel={JS.patch("#{role_base_path(@current_user.role)}/tags")}>
          <.live_component
            module={BeamFlowWeb.TagLive.FormComponent}
            id={@tag.id || :new}
            title={@page_title}
            action={@live_action}
            tag={@tag}
            current_user={@current_user}
            navigate={"#{role_base_path(@current_user.role)}/tags"}
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
