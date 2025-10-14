defmodule Tiki.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Tiki.Repo

  alias Tiki.Accounts.{User, UserToken, UserNotifier}

  use Gettext, backend: TikiWeb.Gettext

  @doc """
  Lists all users.

  Options:
    * `:limit` - The maximum number of users to return.
    * `:order_by` - Field to order by (default: :inserted_at)
    * `:order_direction` - Direction to order (:asc or :desc, default: :desc)
    * `:preload` - List of associations to preload
  """
  def list_users(opts \\ []) do
    limit = Keyword.get(opts, :limit, nil)
    order_by = Keyword.get(opts, :order_by, :inserted_at)
    order_direction = Keyword.get(opts, :order_direction, :desc)
    preload = Keyword.get(opts, :preload, [])

    User
    |> order_by([u], [{^order_direction, field(u, ^order_by)}])
    |> limit(^limit)
    |> preload(^preload)
    |> Repo.all()
  end

  @doc """
  Searches users by email, first name, or last name.

  ## Examples

      iex> search_users("adrian")
      [%User{}, %User{}]

      iex> search_users("john", preload: [:memberships])
      [%User{memberships: [...]}, %User{memberships: [...]}]
  """
  def search_users(search_term, opts \\ []) do
    preload = Keyword.get(opts, :preload, [])

    query =
      from u in User,
        where:
          fragment("? <% ?", ^search_term, u.full_name) or
            fragment("? <% ?", ^search_term, u.email) or
            fragment("? <% ?", ^search_term, u.kth_id),
        preload: ^preload

    Repo.all(query)
  end

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
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert(returning: [:full_name])
  end

  @doc """
  Either creates a new user, or returns an existing user with the same KTH ID.

  Returns `{:ok, user}` if successful, or `{:error, changeset}` on failure.
  """
  def upsert_user_with_userinfo(%{"kth_id" => id, "email" => email} = attrs)
      when is_binary(email) do
    case Repo.get_by(User, kth_id: id) do
      nil ->
        %User{confirmed_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)}
        |> User.oidcc_changeset(attrs)
        |> Repo.insert()

      user ->
        {:ok, user}
    end
  end

  @doc """
  Links a user with a given KTH ID, if it not already taken.

  Year tag is optional.
  """
  def link_user_with_userinfo(user, %{"kth_id" => id} = attrs) do
    case Repo.get_by(User, kth_id: id) do
      nil ->
        # Include kth_id and year_tag if present
        link_attrs = Map.take(attrs, ["kth_id", "year_tag"])

        User.oidcc_changeset(user, link_attrs)
        |> Repo.update()

      found_user when found_user.id == user.id ->
        # User already has this kth_id, update year_tag if provided
        link_attrs = Map.take(attrs, ["kth_id", "year_tag"])

        User.oidcc_changeset(found_user, link_attrs)
        |> Repo.update()

      found_user when found_user.id != user.id ->
        {:error,
         gettext(
           "A user with this KTH-id already exists. Try signing out and logging in directly with your KTH account."
         )}
    end
  end

  @doc """
  Either creates a new user, or returns an existing user with the same email.
  """
  def upsert_user_email(email, name, opts \\ []) do
    locale = Keyword.get(opts, :locale, "en")

    case Repo.get_by(User, email: email) do
      nil ->
        [first_name | last_name] = String.split(name, " ", parts: 2, trim: true)
        last_name = Enum.join(last_name, " ")

        User.email_changeset(%User{}, %{
          email: email,
          first_name: first_name,
          last_name: last_name,
          locale: locale
        })
        |> Repo.insert()

      user ->
        {:ok, user}
    end
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
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp user_email_multi(user, email, context) do
    changeset =
      user
      |> User.email_changeset(%{email: email})
      |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, [context]))
  end

  @doc """
  Gets the user with the given magic link token.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link.

  There are two cases to consider:

  1. The user has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The user has not confirmed their email.
     In this case, the user gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  """
  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> update_user_and_delete_all_tokens()

      {user, token} ->
        Repo.delete!(token)
        {:ok, user, []}

      nil ->
        {:error, :not_found}
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/account/confirm_email/#{&1})")
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc ~S"""
  Delivers the magic link login instructions to the given user.
  """
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Returns an %Ecto.Changeset{}  for changing user settings (but not email or passsord)
  """
  def change_user_data(user, attrs \\ %{}) do
    User.user_data_changeset(user, attrs)
  end

  @doc """
  Updates user settings
  """
  def update_user_data(user, attrs) do
    user
    |> User.user_data_changeset(attrs)
    |> Repo.update()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)

    case Repo.one(query) do
      %UserToken{user: user} -> user
      nil -> nil
    end
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
  Updates user account by an administrator.
  This function should only be used by administrators.
  """
  def admin_update_user(user, attrs) do
    user
    |> Ecto.Changeset.cast(attrs, [
      :email,
      :first_name,
      :last_name,
      :kth_id,
      :year_tag,
      :confirmed_at,
      :locale
    ])
    |> Ecto.Changeset.validate_required([:email])
    |> Repo.update()
  end

  @doc """
  Deletes a user account.
  This function should only be used by administrators.
  """
  def delete_user(user) do
    Repo.delete(user)
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    %{data: %User{} = user} = changeset

    with {:ok, %{user: user, tokens_to_expire: expired_tokens}} <-
           Ecto.Multi.new()
           |> Ecto.Multi.update(:user, changeset)
           |> Ecto.Multi.all(:tokens_to_expire, UserToken.user_and_contexts_query(user, :all))
           |> Ecto.Multi.delete_all(:tokens, fn %{tokens_to_expire: tokens_to_expire} ->
             UserToken.delete_all_query(tokens_to_expire)
           end)
           |> Repo.transaction() do
      {:ok, user, expired_tokens}
    end
  end
end
