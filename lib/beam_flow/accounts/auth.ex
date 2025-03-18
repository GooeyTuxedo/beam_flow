defmodule BeamFlow.Accounts.Auth do
  @moduledoc """
  Provides authorization functions for the application.
  """

  alias BeamFlow.Accounts.User
  alias BeamFlow.Roles

  @doc """
  Checks if a user has a specific role or higher.

  Roles hierarchy (highest to lowest):
  - admin
  - editor
  - author
  - subscriber
  """
  def has_role?(user, role), do: Roles.has_role?(user, role)

  @doc """
  Checks if a user can perform a specific action on a resource.

  Default permissions:
  - admin: can do everything
  - editor: can edit all content and manage authors/subscribers
  - author: can create and edit own content
  - subscriber: can view content and manage own profile
  """
  def can?(nil, _action, _resource), do: false
  def can?(%User{role: :admin}, _action, _resource), do: true

  def can?(%User{role: :editor}, action, resource)
      when action in [:read, :create, :update, :delete] do
    case resource do
      {:user, %User{role: role}} when role in [:author, :subscriber] -> true
      {:post, _foo} -> true
      {:category, _foo} -> true
      {:tag, _foo} -> true
      {:media, _foo} -> true
      {:comment, _foo} -> true
      _else -> false
    end
  end

  def can?(%User{id: user_id, role: :author}, action, resource) do
    case {action, resource} do
      {:read, _foo} -> true
      {:create, {:post, _foo}} -> true
      {:update, {:post, %{user_id: ^user_id}}} -> true
      {:delete, {:post, %{user_id: ^user_id}}} -> true
      {:create, {:media, _foo}} -> true
      {:update, {:media, %{user_id: ^user_id}}} -> true
      {:delete, {:media, %{user_id: ^user_id}}} -> true
      _else -> false
    end
  end

  def can?(%User{id: user_id, role: :subscriber}, action, resource) do
    case {action, resource} do
      {:read, _foo} -> true
      {:create, {:comment, _foo}} -> true
      {:update, {:comment, %{user_id: ^user_id}}} -> true
      {:delete, {:comment, %{user_id: ^user_id}}} -> true
      _else -> false
    end
  end

  @doc """
  Authorizes an action and returns :ok if authorized, otherwise {:error, :unauthorized}.

  This is intended to be used in controller or context functions.
  """
  def authorize(user, action, resource) do
    if can?(user, action, resource) do
      :ok
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Returns a list of all actions a user can perform on a specific resource type.
  This is useful for generating UI elements based on permissions.
  """
  def available_actions(user, resource_type, resource) do
    case user do
      %User{role: :admin} ->
        all_actions()

      %User{role: :editor} ->
        editor_actions(resource_type)

      %User{role: :author, id: user_id} ->
        author_actions(resource_type, resource, user_id)

      %User{role: :subscriber, id: user_id} ->
        subscriber_actions(resource_type, resource, user_id)

      nil ->
        guest_actions(resource_type)
    end
  end

  # Helper functions for each role
  defp all_actions, do: [:create, :read, :update, :delete]

  defp editor_actions(resource_type) do
    case resource_type do
      :post -> [:create, :read, :update, :delete]
      :category -> [:create, :read, :update, :delete]
      :tag -> [:create, :read, :update, :delete]
      :comment -> [:read, :update, :delete]
      :user -> [:read, :update]
      _other -> [:read]
    end
  end

  defp author_actions(:post, resource, user_id) do
    base_actions = [:create, :read]

    if owns_resource?(resource, user_id),
      do: base_actions ++ [:update, :delete],
      else: base_actions
  end

  defp author_actions(:media, resource, user_id) do
    base_actions = [:create, :read]

    if owns_resource?(resource, user_id),
      do: base_actions ++ [:update, :delete],
      else: base_actions
  end

  defp author_actions(:comment, resource, user_id) do
    base_actions = [:create, :read]

    if owns_resource?(resource, user_id),
      do: base_actions ++ [:update, :delete],
      else: base_actions
  end

  defp author_actions(_resource_type, _resource, _user_id), do: [:read]

  defp subscriber_actions(:comment, resource, user_id) do
    base_actions = [:create, :read]

    if owns_resource?(resource, user_id),
      do: base_actions ++ [:update, :delete],
      else: base_actions
  end

  defp subscriber_actions(_resource_type, _resource, _user_id), do: [:read]

  defp guest_actions(_resource_type), do: [:read]

  # Helper to check if a user owns a resource
  defp owns_resource?(nil, _user_id), do: false
  defp owns_resource?(%{user_id: resource_user_id}, user_id), do: resource_user_id == user_id
  defp owns_resource?(_resource, _user_id), do: false
end
