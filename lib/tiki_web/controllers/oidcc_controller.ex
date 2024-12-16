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
      scopes: ["openid", "profile", "email", "pls_tiki"]
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

  def authorize(conn, _params) do
    conn
  end

  def callback(
        %Plug.Conn{private: %{Oidcc.Plug.AuthorizationCallback => {:ok, {token, userinfo}}}} =
          conn,
        _params
      ) do
    userinfo =
      Map.new(userinfo, fn {k, v} ->
        key = Map.get(@key_replacements, k, k)
        {key, v}
      end)

    case Accounts.upsert_user_with_userinfo(userinfo) do
      {:ok, _user} -> UserAuth.log_in_user(conn, token)
      {:error, changeset} -> conn |> put_status(400) |> render(:error, reason: changeset)
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
