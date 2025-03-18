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

      iex> has_role?(%User{role: :admin}, :unknown_role)
      false
  """
  def has_role?(nil, _role), do: false
  def has_role?(_user, role) when not is_atom(role), do: false
  def has_role?(_user, role) when role not in [:admin, :editor, :author, :subscriber], do: false

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

  ## Examples

      iex> role_hierarchy()
      %{admin: 4, editor: 3, author: 2, subscriber: 1}
  """
  def role_hierarchy, do: @role_hierarchy

  @doc """
  Gets the role level from the hierarchy.

  ## Examples

      iex> role_level(:admin)
      4

      iex> role_level(:unknown)
      0
  """
  def role_level(role) when is_atom(role) do
    @role_hierarchy[role] || 0
  end

  @doc """
  Checks if a role exists in the hierarchy.

  ## Examples

      iex> role_exists?(:admin)
      true

      iex> role_exists?(:unknown)
      false
  """
  def role_exists?(role) when is_atom(role) do
    Map.has_key?(@role_hierarchy, role)
  end

  @doc """
  Returns a human-readable name for a role.

  ## Examples

      iex> role_name(:admin)
      "Administrator"

      iex> role_name(:unknown)
      "Unknown Role"
  """
  def role_name(role) do
    case role do
      :admin -> "Administrator"
      :editor -> "Editor"
      :author -> "Author"
      :subscriber -> "Subscriber"
      _unknown -> "Unknown Role"
    end
  end

  @doc """
  Returns a short description of role permissions.

  ## Examples

      iex> role_description(:admin)
      "Full access to all system features and settings."
  """
  def role_description(role) do
    case role do
      :admin -> "Full access to all system features and settings."
      :editor -> "Can edit all content and manage authors and subscribers."
      :author -> "Can create and manage own content."
      :subscriber -> "Can read content and post comments."
      _unknown -> "Unknown role with no defined permissions."
    end
  end
end
