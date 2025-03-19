defmodule BeamFlowWeb.DashboardComponents do
  @moduledoc """
  Provides UI components for all dashboard types (admin, editor, author).

  The components in this module use Tailwind CSS, a utility-first CSS framework.
  See the [Tailwind CSS documentation](https://tailwindcss.com) to learn how to
  customize them or feel free to swap in another framework altogether.
  """
  # This includes the verified_routes with sigil_p
  use BeamFlowWeb, :html

  # We can just import CoreComponents to use the built-in modal
  import BeamFlowWeb.CoreComponents

  @doc """
  Renders the dashboard layout with navigation and header.
  """
  attr :page_title, :string, default: "Dashboard"
  attr :current_user, :map, required: true
  attr :dashboard_type, :atom, default: :admin
  slot :inner_block, required: true

  def dashboard_layout(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100">
      <.dashboard_nav current_user={@current_user} dashboard_type={@dashboard_type} />

      <header class="bg-white shadow">
        <div class="mx-auto py-6 px-4 sm:px-6 lg:px-8">
          <h1 class="text-3xl font-bold text-gray-900">
            {@page_title}
          </h1>
        </div>
      </header>

      <main>
        <div class="mx-auto py-6 sm:px-6 lg:px-8">
          <div class="px-4 py-6 sm:px-0">
            {render_slot(@inner_block)}
          </div>
        </div>
      </main>
    </div>
    """
  end

  @doc """
  Renders the navigation bar for different dashboard types.
  """
  attr :current_user, :map, required: true
  attr :dashboard_type, :atom, default: :admin

  def dashboard_nav(assigns) do
    bg_color = dashboard_bg_color(assigns.dashboard_type)
    hover_color = dashboard_hover_color(assigns.dashboard_type)
    brand_name = dashboard_brand_name(assigns.dashboard_type)

    assigns =
      assigns
      |> assign(:bg_color, bg_color)
      |> assign(:hover_color, hover_color)
      |> assign(:brand_name, brand_name)

    ~H"""
    <nav class={@bg_color}>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-16">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <span class="text-white font-bold">{@brand_name}</span>
            </div>
            <div class="hidden md:block">
              <div class="ml-10 flex items-baseline space-x-4">
                <.nav_link
                  navigate={get_dashboard_home_path(@dashboard_type)}
                  active={true}
                  dashboard_type={@dashboard_type}
                >
                  Dashboard
                </.nav_link>
                <.nav_link
                  navigate={get_posts_path(@dashboard_type)}
                  active={false}
                  dashboard_type={@dashboard_type}
                >
                  {if @dashboard_type == :author, do: "My Posts", else: "Posts"}
                </.nav_link>

                <%= if @dashboard_type == :admin do %>
                  <.nav_link
                    navigate={~p"/admin/users"}
                    active={false}
                    dashboard_type={@dashboard_type}
                  >
                    Users
                  </.nav_link>
                <% end %>

                <%= if @dashboard_type == :editor do %>
                  <.nav_link navigate="#" active={false} dashboard_type={@dashboard_type}>
                    Comments
                  </.nav_link>
                  <.nav_link navigate="#" active={false} dashboard_type={@dashboard_type}>
                    Media
                  </.nav_link>
                <% end %>

                <%= if @dashboard_type == :author do %>
                  <.nav_link
                    navigate={get_new_post_path(@dashboard_type)}
                    active={false}
                    dashboard_type={@dashboard_type}
                  >
                    New Post
                  </.nav_link>
                <% end %>
              </div>
            </div>
          </div>
          <div class="hidden md:block">
            <div class="ml-4 flex items-center md:ml-6">
              <.link
                navigate={~p"/users/settings"}
                class="p-1 rounded-full text-gray-400 hover:text-white focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-gray-800 focus:ring-white"
              >
                <span class="sr-only">User settings</span>
                <.icon name="hero-cog-6-tooth" class="h-6 w-6" />
              </.link>

              <.link
                navigate={~p"/users/log_out"}
                method="delete"
                class="ml-3 p-1 rounded-full text-gray-400 hover:text-white focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-gray-800 focus:ring-white"
              >
                <span class="sr-only">Log out</span>
                <.icon name="hero-arrow-right-on-rectangle" class="h-6 w-6" />
              </.link>
            </div>
          </div>
        </div>
      </div>
    </nav>
    """
  end

  @doc """
  Renders a navigation link for dashboard areas.
  """
  attr :navigate, :any, required: true
  attr :active, :boolean, default: false
  attr :dashboard_type, :atom, default: :admin
  slot :inner_block, required: true

  def nav_link(assigns) do
    hover_color = dashboard_hover_color(assigns.dashboard_type)
    active_color = dashboard_active_color(assigns.dashboard_type)

    assigns =
      assigns
      |> assign(:hover_color, hover_color)
      |> assign(:active_color, active_color)

    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "px-3 py-2 rounded-md text-sm font-medium",
        @active && @active_color,
        !@active && "text-gray-300 #{@hover_color}"
      ]}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  Renders a dashboard card with a title, count, and icon.
  """
  attr :title, :string, required: true
  attr :count, :integer, required: true
  attr :icon_path, :string, required: true
  attr :link, :any, required: true
  attr :color, :string, default: "indigo"

  def dashboard_card(assigns) do
    # Extract the color processing into a separate function to reduce complexity
    assigns = add_color_classes(assigns)

    ~H"""
    <div class="bg-white overflow-hidden shadow rounded-lg" data-test-id="dashboard-card">
      <div class="p-5">
        <div class="flex items-center">
          <div class={"flex-shrink-0 #{@bg_color} rounded-md p-3"}>
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
          <.link navigate={@link} class={"font-medium #{@text_color} #{@hover_color}"}>
            View all
          </.link>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a section header with optional subtitle and actions.
  """
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  slot :actions

  def section_header(assigns) do
    ~H"""
    <div class="mb-8 sm:flex sm:items-center sm:justify-between">
      <div class="mb-4 sm:mb-0">
        <h2 class="text-xl font-semibold text-gray-900">{@title}</h2>
        <%= if @subtitle do %>
          <p class="mt-1 text-sm text-gray-500">{@subtitle}</p>
        <% end %>
      </div>
      <%= if @actions != [] do %>
        <div class="flex space-x-3">
          {render_slot(@actions)}
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a primary button
  """
  attr :navigate, :any, default: nil
  attr :patch, :any, default: nil
  attr :href, :any, default: nil
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def btn_primary(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      patch={@patch}
      href={@href}
      class={[
        "inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md",
        "text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2",
        "focus:ring-offset-2 focus:ring-indigo-500",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  Renders a secondary button
  """
  attr :navigate, :any, default: nil
  attr :patch, :any, default: nil
  attr :href, :any, default: nil
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def btn_secondary(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      patch={@patch}
      href={@href}
      class={[
        "inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm",
        "font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none",
        "focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  Renders a panel with heading and optional content
  """
  attr :class, :string, default: nil
  attr :title, :string, default: nil
  slot :inner_block, required: true

  def panel(assigns) do
    ~H"""
    <div class={["bg-white shadow-md rounded-lg overflow-hidden", @class]}>
      <%= if @title do %>
        <div class="px-4 py-5 border-b border-gray-200 sm:px-6">
          <h3 class="text-lg leading-6 font-medium text-gray-900">
            {@title}
          </h3>
        </div>
      <% end %>
      <div class="px-4 py-5 sm:p-6">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  # Helper functions for dashboard types

  defp dashboard_bg_color(:admin), do: "bg-zinc-800"
  defp dashboard_bg_color(:editor), do: "bg-teal-800"
  defp dashboard_bg_color(:author), do: "bg-cyan-800"
  defp dashboard_bg_color(_everyone_else), do: "bg-gray-800"

  defp dashboard_hover_color(:admin), do: "hover:bg-zinc-700 hover:text-white"
  defp dashboard_hover_color(:editor), do: "hover:bg-teal-700 hover:text-white"
  defp dashboard_hover_color(:author), do: "hover:bg-cyan-700 hover:text-white"
  defp dashboard_hover_color(_everyone_else), do: "hover:bg-gray-700 hover:text-white"

  defp dashboard_active_color(:admin), do: "bg-zinc-700 text-white"
  defp dashboard_active_color(:editor), do: "bg-teal-700 text-white"
  defp dashboard_active_color(:author), do: "bg-cyan-700 text-white"
  defp dashboard_active_color(_everyone_else), do: "bg-gray-700 text-white"

  defp dashboard_brand_name(:admin), do: "BeamFlow Admin"
  defp dashboard_brand_name(:editor), do: "BeamFlow Editor"
  defp dashboard_brand_name(:author), do: "BeamFlow Author"
  defp dashboard_brand_name(_everyone_else), do: "BeamFlow Dashboard"

  # Path helper functions based on dashboard type

  defp get_dashboard_home_path(:admin), do: ~p"/admin"
  defp get_dashboard_home_path(:editor), do: ~p"/editor"
  defp get_dashboard_home_path(:author), do: ~p"/author"

  defp get_posts_path(:admin), do: ~p"/admin/posts"
  defp get_posts_path(:editor), do: ~p"/editor/posts"
  defp get_posts_path(:author), do: ~p"/author/posts"

  defp get_new_post_path(:admin), do: ~p"/admin/posts/new"
  defp get_new_post_path(:editor), do: ~p"/editor/posts/new"
  defp get_new_post_path(:author), do: ~p"/author/posts/new"

  # Helper function to add color classes based on the color attribute
  # This reduces the complexity of the dashboard_card function
  defp add_color_classes(assigns) do
    bg_color = get_bg_color(assigns.color)
    text_color = get_text_color(assigns.color)
    hover_color = get_hover_color(assigns.color)

    assigns
    |> assign(:bg_color, bg_color)
    |> assign(:text_color, text_color)
    |> assign(:hover_color, hover_color)
  end

  defp get_bg_color(color) do
    case color do
      "indigo" -> "bg-indigo-500"
      "green" -> "bg-green-500"
      "blue" -> "bg-blue-500"
      "red" -> "bg-red-500"
      "yellow" -> "bg-yellow-500"
      "purple" -> "bg-purple-500"
      _other -> "bg-indigo-500"
    end
  end

  defp get_text_color(color) do
    case color do
      "indigo" -> "text-indigo-600"
      "green" -> "text-green-600"
      "blue" -> "text-blue-600"
      "red" -> "text-red-600"
      "yellow" -> "text-yellow-600"
      "purple" -> "text-purple-600"
      _other -> "text-indigo-600"
    end
  end

  defp get_hover_color(color) do
    case color do
      "indigo" -> "hover:text-indigo-500"
      "green" -> "hover:text-green-500"
      "blue" -> "hover:text-blue-500"
      "red" -> "hover:text-red-500"
      "yellow" -> "hover:text-yellow-500"
      "purple" -> "hover:text-purple-500"
      _other -> "hover:text-indigo-500"
    end
  end
end
