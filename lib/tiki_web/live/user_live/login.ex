defmodule TikiWeb.UserLive.Login do
  use TikiWeb, :live_view

  alias Tiki.Accounts

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <div class="mb-6 text-center">
        <h1 class="text-foreground mb-2 text-2xl font-semibold">
          {gettext("Sign in to your account")}
        </h1>
        <div class="text-muted-foreground text-sm">
          {gettext("Don't have an account?")}
          <.link navigate={~p"/users/register"} class="text-foreground font-semibold hover:underline">
            {gettext("Sign up")}
          </.link>
          {gettext("for an account now.")}
        </div>
      </div>

      <.form
        :let={f}
        for={@form}
        id="login_form_magic"
        action={~p"/users/log_in"}
        phx-update="ignore"
        phx-submit="submit_magic"
        class="space-y-4"
      >
        <.input field={f[:email]} type="email" label="Email" autocomplete="username" required />

        <.button class="w-full">
          {gettext("Log in with email")}&nbsp;<span aria-hidden="true">→</span>
        </.button>
      </.form>

      <div>
        <div class="relative mt-10">
          <div class="absolute inset-0 flex items-center" aria-hidden="true">
            <div class="border-border w-full border-t"></div>
          </div>
          <div class="relative flex justify-center text-sm font-medium leading-6">
            <span class="bg-background px-6">Or continue with</span>
          </div>
        </div>

        <div class="mt-6 grid grid-cols-2 gap-4">
          <.link
            navigate={~p"/oidcc/authorize"}
            class="ring-foreground shadow-xs col-span-2 flex w-full items-center justify-center gap-3 rounded-md px-3 py-2 text-sm font-semibold ring-1 ring-inset hover:bg-accent focus-visible:ring-transparent"
          >
            <img src="/images/dskold.svg" alt="Datasektionen" class="h-5 w-5 aria-hidden:hidden" />
            <span class="text-sm font-semibold leading-6">Datasektionen</span>
          </.link>
        </div>
      </div>

      <div :if={local_mail_adapter?()} class="mt-6 text-sm ">
        <.icon name="hero-exclamation-triangle" class="text-muted-foreground size-5" />
        {gettext("You are running the local mail adapter, you can see all sent emails at")}
        <.link href="/dev/mailbox" class="underline">{gettext("the mailbox page")}</.link>.
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")
    {:ok, assign(socket, form: form)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log_in/#{&1}")
      )
    end

    info =
      gettext(
        "If your email is in our system, you will receive instructions for logging in shortly."
      )

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log_in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:tiki, Tiki.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
