defmodule TikiWeb.UserLive.Confirmation do
  use TikiWeb, :live_view

  alias Tiki.Accounts

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <div :if={!@user.confirmed_at}>
        <.header class="text-center">{gettext("Welcome to Tiki!")}</.header>

        <div class="text-sm">
          {gettext(
            "Hi %{email}! You may go ahead and confirm your account now.",
            email: @user.email
          )}
        </div>

        <.simple_form
          for={@form}
          id="confirmation_form"
          phx-submit="submit"
          action={~p"/users/log_in?_action=confirmed"}
          phx-trigger-action={@trigger_submit}
        >
          <.input field={@form[:token]} type="hidden" />
          <.input field={@form[:remember_me]} type="checkbox" label="Keep me logged in" />
          <:actions>
            <.button phx-disable-with={gettext("Confirming...")} class="w-full">
              {gettext("Confirm my account")}
            </.button>
          </:actions>
        </.simple_form>
      </div>

      <div :if={@user.confirmed_at}>
        <.header class="text-center">{gettext("Welcome back!")}</.header>

        <div class="text-sm">
          {gettext(
            "Hi %{email}! Your log in link is valid, and you may proceed to log in.",
            email: @user.email
          )}
        </div>

        <.simple_form
          for={@form}
          id="login_form"
          phx-submit="submit"
          action={~p"/users/log_in"}
          phx-trigger-action={@trigger_submit}
        >
          <.input field={@form[:token]} type="hidden" />
          <.input field={@form[:remember_me]} type="checkbox" label={gettext("Keep me logged in")} />
          <:actions>
            <.button phx-disable-with={gettext("Logging in...")} class="w-full">
              {gettext("Log in")}
            </.button>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    if user = Accounts.get_user_by_magic_link_token(token) do
      form = to_form(%{"token" => token}, as: "user")

      {:ok, assign(socket, user: user, form: form, trigger_submit: false),
       temporary_assigns: [form: nil]}
    else
      {:ok,
       socket
       |> put_flash(:error, gettext("Login link is invalid or it has expired."))
       |> push_navigate(to: ~p"/users/log_in")}
    end
  end

  def handle_event("submit", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_submit: true)}
  end
end
