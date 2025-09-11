defmodule TikiWeb.OidccController do
  use TikiWeb, :controller

  alias TikiWeb.UserAuth
  alias Tiki.Accounts

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
      scopes: ["openid", "profile", "email"]
    ]
    when action in [:authorize]
  )

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
      case Accounts.link_user_with_userinfo(conn.assigns.current_user, userinfo) do
        {:ok, _user} ->
          put_flash(conn, :info, gettext("Sucessfully linked KTH account."))
          |> redirect(to: ~p"/account/settings")

        {:error, error} when is_binary(error) ->
          conn |> put_flash(:error, error) |> redirect(to: ~p"/account/settings")

        {:error, changeset} ->
          conn |> put_status(400) |> render(:error, reason: changeset)
      end
    else
      case Accounts.upsert_user_with_userinfo(userinfo) do
        {:ok, user} -> UserAuth.log_in_user(conn, user)
        {:error, changeset} -> conn |> put_status(400) |> render(:error, reason: changeset)
      end
    end
  end

  def callback(
        %Plug.Conn{private: %{Oidcc.Plug.AuthorizationCallback => {:error, reason}}} = conn,
        _params
      ) do
    conn |> put_status(400) |> render(:error, reason: reason)
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
