defmodule TikiWeb.UserSessionController do
  use TikiWeb, :controller

  alias Tiki.Accounts
  alias TikiWeb.UserAuth

  def create(conn, %{"_action" => "confirmed"} = params) do
    create(conn, params, gettext("User confirmed successfully."))
  end

  def create(conn, params) do
    create(conn, params, gettext("Welcome back!"))
  end

  # admin override login
  def hijack(conn, %{"user_id" => user_id}) do
    user =
      get_session(conn, :user_token)
      |> Accounts.get_user_by_session_token()

    with %Accounts.User{} = user <- user,
         :ok <- Tiki.Policy.authorize(:tiki_admin, user),
         %Accounts.User{} = hijack_user <- Accounts.get_user!(user_id) do
      conn
      |> put_flash(:info, gettext("You are now logged in as %{user}", user: hijack_user.email))
      |> UserAuth.log_in_user(hijack_user)
    else
      _ ->
        conn
        |> put_flash(:error, gettext("You are not authorized to do this."))
        |> redirect(to: ~p"/users/log_in")
    end
  end

  # magic link login
  defp create(conn, %{"user" => %{"token" => token} = user_params}, info) do
    case Accounts.login_user_by_magic_link(token) do
      {:ok, user, _} ->
        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, user_params)

      _ ->
        conn
        |> put_flash(:error, gettext("The link is invalid or it has expired."))
        |> redirect(to: ~p"/users/log_in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, gettext("Logged out successfully."))
    |> UserAuth.log_out_user()
  end

  def set_team(conn, %{"team_id" => team_id}) do
    conn
    |> put_session(:current_team_id, team_id)
    |> redirect(to: ~p"/admin")
  end

  def clear_team(conn, _params) do
    conn
    |> put_session(:current_team_id, nil)
    |> redirect(to: ~p"/admin")
  end
end
