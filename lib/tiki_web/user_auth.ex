defmodule TikiWeb.UserAuth do
  use TikiWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller
  require Logger

  alias Tiki.Accounts
  alias Tiki.Teams
  use Gettext, backend: TikiWeb.Gettext

  @doc """
  Logs the user in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.

  It also sets a `:live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out. The line can be safely removed
  if you are not using LiveView.
  """
  def log_in_user(conn, token, _params \\ %{}) do
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> renew_session()
    |> put_token_in_session(token)
    |> redirect(to: user_return_to || signed_in_path(conn))
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn) do
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.delete_user_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      TikiWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> redirect(to: ~p"/")
  end

  @doc """
  Authenticates the user by looking into the session
  and remember me token.
  """
  def fetch_current_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)

    claims = user_token && validate_token(user_token)
    user = claims && Accounts.get_user_by_subject(claims["sub"])

    team =
      case get_session(conn, :current_team_id) do
        nil -> nil
        team_id -> Teams.get_team(team_id)
      end

    conn = if user, do: put_session(conn, :locale, user.locale), else: conn

    assign(conn, :current_user, user)
    |> assign(:current_team, team)
    |> assign(:testthing, %{foo: "bar"})
  end

  @doc """
  Fetches the locale from the session and assigns it to the socket.
  """
  def fetch_locale(conn, _opts) do
    locale = get_session(conn, :locale) || "en"
    Gettext.put_locale(TikiWeb.Gettext, locale)
    Cldr.put_locale(Tiki.Cldr, locale)
    conn
  end

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      {nil, conn}
    end
  end

  @doc """
  Validates a JWT token.
  """
  def validate_token(access_token) do
    provider = Tiki.OpenIdConfigurationProvider
    client_id = TikiWeb.OidccController.client_id()
    client_secret = TikiWeb.OidccController.client_secret()

    with {:ok, client_context} <-
           Oidcc.ClientContext.from_configuration_worker(provider, client_id, client_secret),
         {:ok, claims} <- Oidcc.Token.validate_id_token(access_token, client_context, :any) do
      claims
    else
      {:error, :token_expired} ->
        nil

      {:error, reason} ->
        Logger.error("Error validating token: #{inspect(reason)}")
        nil
    end
  end

  @doc """
  Handles mounting and authenticating the current_user in LiveViews.

  ## `on_mount` arguments

    * `:mount_current_user` - Assigns current_user
      to socket assigns based on user_token, or nil if
      there's no user_token or no matching user.

    * `:ensure_authenticated` - Authenticates the user from the session,
      and assigns the current_user to socket assigns based
      on user_token.
      Redirects to login page if there's no logged user.

    * `:redirect_if_user_is_authenticated` - Authenticates the user from the session.
      Redirects to signed_in_path if there's a logged user.

  ## Examples

  Use the `on_mount` lifecycle macro in LiveViews to mount or authenticate
  the current_user:

      defmodule TikiWeb.PageLive do
        use TikiWeb, :live_view

        on_mount {TikiWeb.UserAuth, :mount_current_user}
        ...
      end

  Or use the `live_session` of your router to invoke the on_mount callback:

      live_session :authenticated, on_mount: [{TikiWeb.UserAuth, :ensure_authenticated}] do
        live "/profile", ProfileLive, :index
      end
  """
  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, mount_current_user(session, socket)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_user(session, socket)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, gettext("You must log in to access this page."))
        |> Phoenix.LiveView.redirect(to: ~p"/users/log_in")

      {:halt, socket}
    end
  end

  def on_mount(:ensure_admin, _params, session, socket) do
    socket = mount_current_user(session, socket)

    if socket.assigns.current_user do
      case socket.assigns.current_user.role do
        :admin ->
          {:cont, socket}

        _ ->
          socket =
            socket
            |> Phoenix.LiveView.put_flash(
              :error,
              gettext("You need to be an admin to access this page.")
            )
            |> Phoenix.LiveView.redirect(to: ~p"/users/log_in")

          {:halt, socket}
      end
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, gettext("You must log in to access this page."))
        |> Phoenix.LiveView.redirect(to: ~p"/users/log_in")

      {:halt, socket}
    end
  end

  def on_mount(:ensure_team, _params, session, socket) do
    socket = mount_current_user(session, socket)

    if socket.assigns.current_team do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(
          :error,
          gettext("You must select a team to access this page.")
        )
        |> Phoenix.LiveView.redirect(to: ~p"/admin/teams")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    socket = mount_current_user(session, socket)

    if socket.assigns.current_user do
      {:halt, Phoenix.LiveView.redirect(socket, to: signed_in_path(socket))}
    else
      {:cont, socket}
    end
  end

  defp mount_current_user(session, socket) do
    Phoenix.Component.assign_new(socket, :current_user, fn ->
      if user_token = session["user_token"] do
        claims = user_token && validate_token(user_token)
        user = claims && Accounts.get_user_by_subject(claims["sub"])

        if user do
          locale = Map.get(user, :locale, "en")
          Gettext.put_locale(TikiWeb.Gettext, locale)
          Cldr.put_locale(Tiki.Cldr, locale)
        end

        user
      end
    end)
    |> Phoenix.Component.assign_new(:current_team, fn ->
      with team_id when not is_nil(team_id) <- session["current_team_id"],
           %Tiki.Teams.Team{} = team <- Teams.get_team(team_id) do
        team
      end
    end)
  end

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.

  If you want to enforce the user email is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/users/log_in")
      |> halt()
    end
  end

  def require_admin_user(conn, opts) do
    conn = require_authenticated_user(conn, opts)

    if Tiki.Policy.authorize?(:tiki_admin, conn.assigns.current_user) do
      conn
    else
      conn
      |> put_flash(:error, "You need to be an admin to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/users/log_in")
      |> halt()
    end
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:user_token, token.id.token)
    |> put_session(:live_socket_id, "users_sessions:#{token.access.token}")
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(_conn), do: ~p"/"
end
