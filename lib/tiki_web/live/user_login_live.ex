defmodule TikiWeb.UserLoginLive do
  use TikiWeb, :live_view

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

      <.simple_form for={@form} id="login_form" action={~p"/account/log_in"} phx-update="ignore">
        <.input field={@form[:email]} type="email" label="Email" required />
        <.input field={@form[:password]} type="password" label="Password" required />

        <:actions>
          <.input field={@form[:remember_me]} type="checkbox" label="Keep me logged in" />
          <.link href={~p"/users/reset_password"} class="text-sm font-semibold">
            Forgot your password?
          </.link>
        </:actions>
        <:actions>
          <.button phx-disable-with="Signing in..." class="w-full">
            Sign in <span aria-hidden="true">→</span>
          </.button>
        </:actions>
      </.simple_form>

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
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")
    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end
end
