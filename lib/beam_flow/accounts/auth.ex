defmodule BeamFlow.Accounts.Auth do
  @moduledoc """
  Provides authorization functions for the application.
  """

  alias BeamFlow.Accounts.User

  @doc """
  Checks if a user has a specific role or higher.

  Roles hierarchy (highest to lowest):
  - admin
  - editor
  - author
  - subscriber
  """
  def has_role?(nil, _role), do: false

  def has_role?(%User{role: user_role}, required_role) do
    role_hierarchy = %{
      admin: 4,
      editor: 3,
      author: 2,
      subscriber: 1
    }

    role_hierarchy[user_role] >= role_hierarchy[required_role]
  end

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
end
