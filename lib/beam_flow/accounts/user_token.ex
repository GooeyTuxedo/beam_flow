defmodule BeamFlow.Accounts.UserToken do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Query

  @hash_algorithm :sha256
  @rand_size 32

  # It is very important to keep the reset password token expiry short,
  # since someone with access to the email may take over the account.
  @reset_password_validity_in_days 1
  @confirm_validity_in_days 7
  @change_email_validity_in_days 7
  @session_validity_in_days 60
  @remember_me_validity_in_days 180
  @api_token_validity_in_days 30

  schema "users_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string
    belongs_to :user, BeamFlow.Accounts.User

    timestamps(updated_at: false)
  end

  @doc """
  Generates a token that will be stored in a signed place,
  such as session or cookie. As they are signed, those
  tokens do not need to be hashed.

  The reason why we store session tokens in the database, even
  though Phoenix already provides a session cookie, is because
  Phoenix's default session cookies are not persisted, they are
  simply signed and potentially encrypted. This means they are
  valid indefinitely, unless you change the signing/encryption
  salt.

  Therefore, we want to store them in the database to avoid
  long-lived sessions in case our signing or encryption key changes.
  A session token is valid for a default of 60 days, but this can
  be extended up to 180 days with the remember_me option.
  """
  def build_session_token(user, remember_me \\ false) do
    token = :crypto.strong_rand_bytes(@rand_size)

    validity_days =
      if remember_me, do: @remember_me_validity_in_days, else: @session_validity_in_days

    {token,
     %BeamFlow.Accounts.UserToken{
       token: token,
       context: "session",
       user_id: user.id,
       inserted_at: build_token_timestamp(validity_days)
     }}
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the user found by the token, if any.

  The token is valid if it matches the value in the database and it has
  not expired (after @session_validity_in_days).
  """
  def verify_session_token_query(token) do
    query =
      from token in token_and_context_query(token, "session"),
        join: user in assoc(token, :user),
        where:
          token.inserted_at >
            ago(^max(@session_validity_in_days, @remember_me_validity_in_days), "day"),
        select: user

    {:ok, query}
  end

  @doc """
  Builds an API token for authenticating API requests.
  """
  def build_api_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token)

    {Base.url_encode64(token, padding: false),
     %BeamFlow.Accounts.UserToken{
       token: hashed_token,
       context: "api",
       user_id: user.id,
       inserted_at: build_token_timestamp(@api_token_validity_in_days)
     }}
  end

  @doc """
  Returns the token struct for the given token value and context.
  """
  def verify_api_token_query(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)

        query =
          from token in token_and_context_query(hashed_token, "api"),
            join: user in assoc(token, :user),
            where: token.inserted_at > ago(@api_token_validity_in_days, "day"),
            select: user

        {:ok, query}

      :error ->
        :error
    end
  end

  @doc """
  Builds a token with a hashed counter part.

  The non-hashed token is sent to the user email while the
  hashed part is stored in the database, to avoid reconstruction.
  The token is valid for a week as long as users don't change
  their email.
  """
  def build_email_token(user, context) do
    build_hashed_token(user, context, user.email)
  end

  defp build_hashed_token(user, context, sent_to) do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token)

    {Base.url_encode64(token, padding: false),
     %BeamFlow.Accounts.UserToken{
       token: hashed_token,
       context: context,
       sent_to: sent_to,
       user_id: user.id
     }}
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the user found by the token, if any.

  The given token is valid if it matches its hashed counterpart in the
  database and the user email has not changed.
  """
  def verify_email_token_query(token, context) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)
        days = days_for_context(context)

        query =
          from token in token_and_context_query(hashed_token, context),
            join: user in assoc(token, :user),
            where: token.inserted_at > ago(^days, "day") and token.sent_to == user.email,
            select: user

        {:ok, query}

      :error ->
        :error
    end
  end

  # Alias for backwards compatibility
  def verify_change_email_token_query(token, context),
    do: verify_email_token_query(token, context)

  # Fixed implementation to handle "change:" prefixed contexts correctly
  defp days_for_context("confirm"), do: @confirm_validity_in_days
  defp days_for_context("reset_password"), do: @reset_password_validity_in_days

  defp days_for_context(context) when is_binary(context) do
    if String.starts_with?(context, "change:") do
      @change_email_validity_in_days
    else
      raise "unknown context #{inspect(context)}"
    end
  end

  @doc """
  Returns the token struct for the given token value and context.
  """
  def token_and_context_query(token, context) do
    from BeamFlow.Accounts.UserToken, where: [token: ^token, context: ^context]
  end

  # Alias for backwards compatibility
  def by_token_and_context_query(token, context), do: token_and_context_query(token, context)

  @doc """
  Gets all tokens for the given user for the given contexts.
  """
  def user_and_contexts_query(user, :all) do
    from t in BeamFlow.Accounts.UserToken, where: t.user_id == ^user.id
  end

  def user_and_contexts_query(user, contexts) do
    from t in BeamFlow.Accounts.UserToken, where: t.user_id == ^user.id and t.context in ^contexts
  end

  # Alias for backwards compatibility
  def by_user_and_contexts_query(user, contexts), do: user_and_contexts_query(user, contexts)

  # Creates a timestamp for the token based on days from now, ensuring microseconds are truncated
  defp build_token_timestamp(days) do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.add(days * 24 * 60 * 60, :second)
    |> NaiveDateTime.truncate(:second)
  end
end
