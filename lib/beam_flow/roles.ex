defmodule BeamFlow.Roles do
  @moduledoc """
  Centralized role management for the BeamFlow CMS.
  Handles role hierarchy, role checking, and provides utility functions
  for working with user roles.
  """

  @role_hierarchy %{
    admin: 4,
    editor: 3,
    author: 2,
    subscriber: 1
  }

  @doc """
  Checks if a user has a specific role or higher in the hierarchy.

  ## Examples

      iex> has_role?(%User{role: :admin}, :editor)
      true

      iex> has_role?(%User{role: :author}, :admin)
      false

      iex> has_role?(nil, :subscriber)
      false
  """
  def has_role?(nil, _role), do: false

  def has_role?(user, role) when is_atom(role) do
    user_role_level = @role_hierarchy[user.role] || 0
    required_role_level = @role_hierarchy[role] || 0

    user_role_level >= required_role_level
  end

  @doc """
  Gets all roles that a user satisfies based on the hierarchy.

  ## Examples

      iex> get_user_roles(%User{role: :editor})
      [:editor, :author, :subscriber]

      iex> get_user_roles(nil)
      []
  """
  def get_user_roles(nil), do: []

  def get_user_roles(user) do
    user_level = @role_hierarchy[user.role] || 0

    @role_hierarchy
    |> Enum.filter(fn {_role, level} -> user_level >= level end)
    |> Enum.map(fn {role, _level} -> role end)
  end

  @doc """
  Returns all roles in descending order of privilege.

  ## Examples

      iex> all_roles()
      [:admin, :editor, :author, :subscriber]
  """
  def all_roles do
    @role_hierarchy
    |> Enum.sort_by(fn {_role, level} -> level end, :desc)
    |> Enum.map(fn {role, _level} -> role end)
  end

  @doc """
  Returns the role hierarchy as a map.
  """
  def role_hierarchy, do: @role_hierarchy
end
