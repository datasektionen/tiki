defmodule TikiWeb.OidccController do
  use TikiWeb, :controller

  alias TikiWeb.UserAuth
  alias Tiki.Accounts
  require Logger

  @key_replacements %{
    "sub" => "kth_id",
    "given_name" => "first_name",
    "family_name" => "last_name"
  }

  plug(
    Oidcc.Plug.Authorize,
    [
      provider: Tiki.OpenIdConfigurationProvider,
      client_id: &__MODULE__.client_id/0,
      client_secret: &__MODULE__.client_secret/0,
      redirect_uri: &__MODULE__.callback_uri/0,
      scopes: ["openid", "profile", "email", "year_tag"]
    ]
    when action in [:authorize]
  )

  def authorize(conn, _params) do
    conn
  end

  def authorize_return(conn, params) do
    return_to = params["return_to"]

    link =
      case params["link"] do
        "true" -> true
        _ -> false
      end

    put_session(conn, :user_return_to, return_to)
    |> put_session(:link_account, link)
    |> redirect(to: ~p"/oidcc/authorize")
  end

  plug(
    Oidcc.Plug.AuthorizationCallback,
    [
      provider: Tiki.OpenIdConfigurationProvider,
      client_id: &__MODULE__.client_id/0,
      client_secret: &__MODULE__.client_secret/0,
      redirect_uri: &__MODULE__.callback_uri/0
    ]
    when action in [:callback]
  )

  def callback(
        %Plug.Conn{private: %{Oidcc.Plug.AuthorizationCallback => {:ok, {_token, userinfo}}}} =
          conn,
        _params
      ) do
    userinfo =
      Map.new(userinfo, fn {k, v} ->
        key = Map.get(@key_replacements, k, k)
        {key, v}
      end)

    if get_session(conn, :link_account) && conn.assigns[:current_user] do
      # User is logged in and wants to link their KTH account
      case Accounts.link_user_with_userinfo(conn.assigns.current_user, userinfo) do
        {:ok, _user} ->
          put_flash(conn, :info, gettext("Sucessfully linked KTH account."))
          |> redirect(to: ~p"/account/settings")

        {:error, error} when is_binary(error) ->
          conn |> put_flash(:error, error) |> redirect(to: ~p"/account/settings")

        {:error, %Ecto.Changeset{} = changeset} ->
          Logger.error("Account linking failed: #{inspect(changeset.errors)}")

          conn
          |> put_flash(
            :error,
            gettext("Unable to link your KTH account. Please try again or contact support.")
          )
          |> redirect(to: ~p"/account/settings")
      end
    else
      # User is logging in via OIDC
      case Accounts.upsert_user_with_userinfo(userinfo) do
        {:ok, user} ->
          UserAuth.log_in_user(conn, user)

        {:error, %Ecto.Changeset{} = changeset} ->
          # Check if this is an email uniqueness error
          if Keyword.has_key?(changeset.errors, :email) do
            {message, _opts} = changeset.errors[:email]

            conn
            |> put_flash(
              :error,
              gettext(
                "Email %{error}. Sign in with your email address and link to your KTH account instead.",
                error: message
              )
            )
            |> redirect(to: ~p"/users/log_in")
          else
            # Other validation errors (e.g., invalid data from OIDC provider)
            Logger.error("OIDC user creation failed: #{inspect(changeset.errors)}")

            conn
            |> put_flash(
              :error,
              gettext(
                "Unable to create your account. Please try again or contact support if the problem persists."
              )
            )
            |> redirect(to: ~p"/users/log_in")
          end
      end
    end
  end

  def callback(
        %Plug.Conn{private: %{Oidcc.Plug.AuthorizationCallback => {:error, reason}}} = conn,
        _params
      ) do
    # Log the error for debugging but don't expose details to user
    Logger.error("OIDC authentication failed: #{inspect(reason)}")

    # Redirect to login with friendly error message instead of rendering error page
    conn
    |> put_flash(
      :error,
      gettext(
        "We encountered a problem signing you in with KTH. Please try again or contact us if the problem persists."
      )
    )
    |> redirect(to: ~p"/users/log_in")
  end

  @doc false
  def client_id do
    Application.fetch_env!(:tiki, Oidcc)[:client_id]
  end

  @doc false
  def client_secret do
    Application.fetch_env!(:tiki, Oidcc)[:client_secret]
  end

  @doc false
  def callback_uri do
    url(~p"/oidcc/callback")
  end
end
