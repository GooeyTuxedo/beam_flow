defmodule BeamFlow.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias BeamFlow.Repo

  alias BeamFlow.Accounts.AuditLog
  alias BeamFlow.Accounts.Auth
  alias BeamFlow.Accounts.User
  alias BeamFlow.Accounts.UserNotifier
  alias BeamFlow.Accounts.UserToken

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs, opts \\ []) do
    %User{}
    |> User.registration_changeset(attrs, opts)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, validate_password: false)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs, validate_email: false)
  end

  @doc """
  Emulates the updating of a user email in test environments without
  actually requiring email verification.
  """
  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    # Extract the query outside of the with, avoid starting with when
    {:ok, query} = UserToken.verify_change_email_token_query(token, context)

    with %User{} = queried_user <- Repo.one(query),
         {:ok, %{user: updated_user}} <- Repo.transaction(user_email_multi(queried_user, context)) do
      {:ok, updated_user}
    else
      _unused_pattern -> :error
    end
  end

  defp user_email_multi(user, context) do
    changeset =
      user
      |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, [context]))
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm_email/#{&1})")
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _unused} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user, remember_me \\ false) do
    {token, user_token} = UserToken.build_session_token(user, remember_me)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  rescue
    # Handle any db errors gracefully
    Ecto.Query.CastError -> nil
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &url(~p"/users/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &url(~p"/users/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      UserNotifier.deliver_confirmation_instructions(user, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _unused -> :error
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, ["confirm"]))
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &url(~p"/users/reset_password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(token) do
    {:ok, query} = UserToken.verify_email_token_query(token, "reset_password")

    with %User{} = user <- Repo.one(query) do
      user
    else
      _unused -> nil
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _unused} -> {:error, changeset}
    end
  end

  ## User Roles and Authorization

  @doc """
  Checks if a user has a specific role.
  """
  def has_role?(user, role) do
    BeamFlow.Roles.has_role?(user, role)
  end

  @doc """
  Checks if a user can perform an action on a resource.
  """
  def can?(user, action, resource) do
    Auth.can?(user, action, resource)
  end

  @doc """
  Authorizes an action and returns :ok or {:error, :unauthorized}.
  """
  def authorize(user, action, resource) do
    Auth.authorize(user, action, resource)
  end

  ## Audit Logging

  @doc """
  Logs an action performed by a user.
  """
  def log_action(action, user_id, opts \\ []) do
    AuditLog.log_action(Repo, action, user_id, opts)
  end

  @doc """
  Gets audit logs for a specific user.
  """
  def list_user_logs(user_id, limit \\ 50) do
    query = AuditLog.list_user_logs(AuditLog, user_id)
    limited_query = limit(query, ^limit)
    Repo.all(limited_query)
  end

  @doc """
  Gets audit logs for a specific resource.
  """
  def list_resource_logs(resource_type, resource_id, limit \\ 50) do
    query = AuditLog.list_resource_logs(AuditLog, resource_type, resource_id)
    limited_query = limit(query, ^limit)
    Repo.all(limited_query)
  end

  @doc """
  Gets recent audit logs.
  """
  def list_recent_logs(limit \\ 50) do
    query = AuditLog.list_recent_logs(AuditLog, limit)
    Repo.all(query)
  end

  @doc """
  Returns a list of all users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Returns a list of users filtered by role.

  ## Examples

      iex> list_users_by_role(:admin)
      [%User{}, ...]

  """
  def list_users_by_role(role) do
    User
    |> where([u], u.role == ^role)
    |> Repo.all()
  end

  @doc """
  Generates an API token for the user.
  """
  def generate_api_token(user) do
    {token, user_token} = UserToken.build_api_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets a user by API token.
  """
  def get_user_by_api_token(token) do
    with {:ok, decoded_token} <- Base.url_decode64(token, padding: false),
         hashed_token = :crypto.hash(:sha256, decoded_token),
         %UserToken{user_id: user_id} <-
           Repo.get_by(UserToken, token: hashed_token, context: "api"),
         %User{} = user <- Repo.get(User, user_id) do
      user
    else
      _error -> nil
    end
  end

  @doc """
  Revokes an API token.
  """
  def revoke_api_token(token) do
    # Fix with statement ending with <- clause
    with {:ok, decoded_token} <- Base.url_decode64(token, padding: false) do
      hashed_token = :crypto.hash(:sha256, decoded_token)

      {count, _deleted} =
        Repo.delete_all(
          from t in UserToken, where: t.token == ^hashed_token and t.context == "api"
        )

      if count > 0, do: :ok, else: :error
    else
      _error -> :error
    end
  end
end
