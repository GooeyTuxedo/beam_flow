defmodule BeamFlowWeb.DashboardComponents do
  @moduledoc """
  Provides UI components for all dashboard types (admin, editor, author).

  These components are designed to be reused across different dashboard
  interfaces while maintaining consistent styling and behavior.
  """
  use BeamFlowWeb, :html

  import BeamFlowWeb.CoreComponents

  #
  # Layout Components
  #

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

                  <% # Placeholder links - will be implemented in future %>
                  <.nav_link href="#" active={false} dashboard_type={@dashboard_type}>
                    Categories
                  </.nav_link>
                  <.nav_link href="#" active={false} dashboard_type={@dashboard_type}>
                    Tags
                  </.nav_link>
                <% end %>

                <%= if @dashboard_type == :editor do %>
                  <% # Placeholder links - will be implemented in future %>
                  <.nav_link href="#" active={false} dashboard_type={@dashboard_type}>
                    Categories
                  </.nav_link>
                  <.nav_link href="#" active={false} dashboard_type={@dashboard_type}>
                    Tags
                  </.nav_link>
                  <.nav_link href="#" active={false} dashboard_type={@dashboard_type}>
                    Comments
                  </.nav_link>
                  <.nav_link href="#" active={false} dashboard_type={@dashboard_type}>
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

  #
  # Navigation Components
  #

  @doc """
  Renders a navigation link for dashboard areas.
  """
  attr :navigate, :any, default: nil
  attr :href, :any, default: nil
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
      href={@href}
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

  #
  # Dashboard Cards and Statistics
  #

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
  Renders a stats card for displaying a metric with percentage change.
  """
  attr :title, :string, required: true
  attr :value, :any, required: true
  attr :previous_value, :any, default: nil
  attr :unit, :string, default: ""
  attr :description, :string, default: nil
  attr :is_currency, :boolean, default: false
  attr :color, :string, default: "indigo"

  def stats_card(assigns) do
    assigns =
      assigns
      |> assign(:change_pct, calculate_change_percentage(assigns.value, assigns.previous_value))
      |> assign(:change_type, determine_change_type(assigns.value, assigns.previous_value))
      |> add_color_classes()

    ~H"""
    <div class="bg-white overflow-hidden shadow rounded-lg">
      <div class="p-5">
        <div class="flex items-center">
          <div class="w-0 flex-1">
            <dt class="text-sm font-medium text-gray-500 truncate">
              {@title}
            </dt>
            <dd class="mt-1">
              <div class="text-2xl font-semibold text-gray-900">
                <%= if @is_currency do %>
                  {format_currency(@value)}
                <% else %>
                  {@value}{@unit}
                <% end %>
              </div>
            </dd>
            <%= if @previous_value != nil do %>
              <dd class="mt-2 flex items-center text-sm">
                <div class={[
                  "flex items-center",
                  @change_type == :increase && "text-green-600",
                  @change_type == :decrease && "text-red-600",
                  @change_type == :neutral && "text-gray-500"
                ]}>
                  <%= if @change_type == :increase do %>
                    <.icon name="hero-arrow-up" class="w-4 h-4 mr-1" />
                  <% end %>
                  <%= if @change_type == :decrease do %>
                    <.icon name="hero-arrow-down" class="w-4 h-4 mr-1" />
                  <% end %>
                  <%= if @change_type == :neutral do %>
                    <.icon name="hero-minus" class="w-4 h-4 mr-1" />
                  <% end %>
                  {abs(@change_pct)}%
                </div>
                <span class="text-gray-500 ml-2">from previous period</span>
              </dd>
            <% end %>
          </div>
        </div>
      </div>
      <%= if @description do %>
        <div class="bg-gray-50 px-5 py-3">
          <div class="text-sm text-gray-500">
            {@description}
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  #
  # Content Organization Components
  #

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

  #
  # Action Components
  #

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

  #
  # Form Components
  #

  @doc """
  Renders a filter form for consistent filtering across dashboards.
  """
  attr :id, :string, required: true
  attr :form, :any, required: true
  attr :phx_change, :string, default: "filter"
  slot :filters, required: true

  def filter_form(assigns) do
    ~H"""
    <.panel title="Filter" class="mb-8">
      <.form for={@form} id={@id} phx-change={@phx_change}>
        <div class="grid grid-cols-1 gap-y-6 gap-x-4 sm:grid-cols-6">
          {render_slot(@filters)}
        </div>
      </.form>
    </.panel>
    """
  end

  @doc """
  Renders tag selection component.
  """
  attr :field, Phoenix.HTML.FormField, required: true
  attr :options, :list, required: true
  attr :label, :string, default: "Tags"

  def tag_selector(assigns) do
    ~H"""
    <div class="space-y-2">
      <.label for={@field.id}>{@label}</.label>
      <div class="flex flex-wrap gap-2 p-2 bg-gray-50 rounded-md border border-gray-200 min-h-16">
        <%= for {tag_id, tag_name, selected} <- @options do %>
          <div class={[
            "px-3 py-1 rounded-full text-sm font-medium cursor-pointer",
            selected && "bg-indigo-100 text-indigo-800 border border-indigo-300",
            !selected && "bg-gray-100 text-gray-800 border border-gray-200 hover:bg-gray-200"
          ]}>
            <label class="cursor-pointer flex items-center space-x-1">
              <input
                type="checkbox"
                name={"#{@field.name}[]"}
                value={tag_id}
                checked={selected}
                class="hidden"
              />
              <span>{tag_name}</span>
              <%= if selected do %>
                <.icon name="hero-check" class="h-4 w-4 text-indigo-600" />
              <% end %>
            </label>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  #
  # Status and Data Display Components
  #

  @doc """
  Renders a status badge with color coding based on status.
  """
  attr :status, :string, required: true
  # sm, md, lg
  attr :size, :string, default: "md"

  def status_badge(assigns) do
    assigns = assign(assigns, :badge_class, status_badge_classes(assigns.status, assigns.size))

    ~H"""
    <span class={@badge_class}>
      {@status}
    </span>
    """
  end

  @doc """
  Renders a simple data list item with title and value.
  """
  attr :title, :string, required: true
  attr :value, :string, required: true

  def data_item(assigns) do
    ~H"""
    <div class="py-4 sm:grid sm:grid-cols-3 sm:gap-4 sm:py-5">
      <dt class="text-sm font-medium text-gray-500">{@title}</dt>
      <dd class="mt-1 text-sm text-gray-900 sm:col-span-2 sm:mt-0">{@value}</dd>
    </div>
    """
  end

  @doc """
  Renders an activity log item.
  """
  # Changed from :map to :any for flexibility
  attr :user, :any, required: true
  attr :action, :string, required: true
  attr :resource_type, :string, required: true
  attr :resource_id, :string, default: nil
  attr :timestamp, :any, required: true
  attr :details, :string, default: nil

  def activity_log_item(assigns) do
    # Handle potentially unloaded user associations
    user_name = get_user_name(assigns.user)
    first_letter = String.first(user_name || "?")

    assigns = assign(assigns, :user_name, user_name)
    assigns = assign(assigns, :first_letter, first_letter)

    ~H"""
    <div class="relative pb-8">
      <span class="absolute top-5 left-5 -ml-px h-full w-0.5 bg-gray-200" aria-hidden="true"></span>
      <div class="relative flex items-start space-x-3">
        <div class="relative">
          <div class="h-10 w-10 rounded-full bg-gray-200 flex items-center justify-center">
            <span class="text-gray-600 font-medium">{@first_letter}</span>
          </div>
        </div>
        <div class="min-w-0 flex-1">
          <div>
            <div class="text-sm">
              <span class="font-medium text-gray-900">{@user_name}</span>
              <span class="text-gray-500">
                <span>{@action}</span>
                <span class="font-medium text-gray-900">{@resource_type}</span>
                <%= if @resource_id do %>
                  <span class="text-gray-500">#{@resource_id}</span>
                <% end %>
              </span>
            </div>
            <p class="mt-0.5 text-sm text-gray-500">
              {format_timestamp(@timestamp)}
            </p>
          </div>
          <%= if @details do %>
            <div class="mt-2 text-sm text-gray-700">
              <p>{@details}</p>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  #
  # Helper functions
  #

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

  defp status_badge_classes(status, size) do
    base_classes = get_size_classes(size)
    color_classes = get_status_color_classes(status)

    "#{base_classes} #{color_classes}"
  end

  defp get_size_classes(size) do
    case size do
      "sm" -> "px-2 inline-flex text-xs leading-5 font-semibold rounded-full"
      "md" -> "px-2.5 py-0.5 inline-flex text-sm leading-5 font-semibold rounded-full"
      "lg" -> "px-3 py-1 inline-flex text-base leading-6 font-semibold rounded-full"
      _other -> "px-2.5 py-0.5 inline-flex text-sm leading-5 font-semibold rounded-full"
    end
  end

  defp get_status_color_classes(status) do
    status_colors = %{
      "draft" => "bg-gray-100 text-gray-800",
      "published" => "bg-green-100 text-green-800",
      "scheduled" => "bg-blue-100 text-blue-800",
      "pending" => "bg-yellow-100 text-yellow-800",
      "rejected" => "bg-red-100 text-red-800",
      "approved" => "bg-green-100 text-green-800",
      "active" => "bg-green-100 text-green-800",
      "inactive" => "bg-gray-100 text-gray-800"
    }

    Map.get(status_colors, status, "bg-gray-100 text-gray-800")
  end

  # Helper function to calculate percentage change
  defp calculate_change_percentage(current, previous)
       when is_number(current) and is_number(previous) and previous != 0 do
    ((current - previous) / previous * 100)
    |> Float.round(1)
  end

  defp calculate_change_percentage(_current, _previous), do: 0.0

  # Helper function to determine change type
  defp determine_change_type(current, previous) when is_number(current) and is_number(previous) do
    cond do
      current > previous -> :increase
      current < previous -> :decrease
      true -> :neutral
    end
  end

  defp determine_change_type(_current, _previous), do: :neutral

  # Helper function to safely get user name
  defp get_user_name(user) do
    cond do
      is_map(user) && Map.has_key?(user, :name) -> user.name
      is_map(user) && Map.has_key?(user, "name") -> user["name"]
      is_binary(user) -> user
      true -> "Unknown User"
    end
  end

  # Helper function to format timestamps
  defp format_timestamp(timestamp) do
    case timestamp do
      %DateTime{} = dt -> Calendar.strftime(dt, "%b %d, %Y %H:%M")
      %NaiveDateTime{} = ndt -> Calendar.strftime(ndt, "%b %d, %Y %H:%M")
      _unknown -> "unknown time"
    end
  end

  # Simple helper for formatting currency without external dependencies
  defp format_currency(value) do
    "$#{:erlang.float_to_binary(value * 1.0, decimals: 2)}"
  end
end
