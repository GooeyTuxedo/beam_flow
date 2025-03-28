defmodule BeamFlow.Accounts.User do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Inspect, except: [:password]}
  schema "users" do
    field :email, :string
    field :name, :string
    field :bio, :string
    field :password, :string, virtual: true, redact: true
    field :password_hash, :string, redact: true
    field :confirmed_at, :naive_datetime
    field :role, Ecto.Enum, values: [:admin, :editor, :author, :subscriber], default: :subscriber

    timestamps()
  end

  @doc """
  A user changeset for registration.

  It is important to validate the length of both email and password.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour. Long passwords may
  also be very expensive to hash for certain algorithms.

  ## Options

    * `:validate_email` - Validates the uniqueness of the email, in case
      you don't want to validate the uniqueness of the email (like when
      using this changeset for validations on a LiveView form before
      submitting the form), this option can be set to `false`.
      Defaults to `true`.
    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form before submitting the form), this option
      can be set to `false`. Defaults to `true`.
    * `:validate_password` - Validates the password strength according to
      the configured strength level. Set to `false` to skip this validation
      (useful during tests). Defaults to `true`.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :name, :password, :role])
    |> validate_email(opts)
    |> validate_name()
    |> validate_password(opts)
  end

  defp validate_name(changeset) do
    changeset
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 60)
  end

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    |> maybe_validate_password_strength(opts)
    |> maybe_hash_password(opts)
  end

  defp maybe_validate_password_strength(changeset, opts) do
    validate_password_strength = Keyword.get(opts, :validate_password, true)

    if validate_password_strength do
      changeset
      |> validate_format(:password, ~r/[a-z]/,
        message: "must have at least one lowercase character"
      )
      |> validate_format(:password, ~r/[A-Z]/,
        message: "must have at least one uppercase character"
      )
      |> validate_format(:password, ~r/[!@#$%^&*(),.?":{}|<>]/,
        message: "must have at least one symbol"
      )
    else
      changeset
    end
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # Using Argon2 for password hashing
      |> put_change(:password_hash, Argon2.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, BeamFlow.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
    |> case do
      %{changes: %{email: _email}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  A user changeset for changing the password.

  ## Options

  * `:hash_password` - Hashes the password so it can be stored securely
    in the database and ensures the password field is cleared to prevent
    leaks in the logs. If password hashing is not needed and clearing the
    password field is not desired (like when using this changeset for
    validations on a LiveView form before submitting the form), this option
    can be set to `false`. Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  A user changeset for changing user profile data.
  """
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :bio])
    |> validate_name()
    |> validate_length(:bio, max: 1000)
  end

  @doc """
  A user changeset for changing the user role.
  """
  def role_changeset(user, attrs) do
    user
    |> cast(attrs, [:role])
    |> validate_required([:role])
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Argon2.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%BeamFlow.Accounts.User{password_hash: password_hash}, password)
      when is_binary(password_hash) and byte_size(password) > 0 do
    Argon2.verify_pass(password, password_hash)
  end

  def valid_password?(_user, _password) do
    Argon2.no_user_verify()
    false
  end

  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  def validate_current_password(changeset, password) do
    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end
end
