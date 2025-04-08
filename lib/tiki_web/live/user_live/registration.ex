defmodule TikiWeb.UserLive.Registration do
  use TikiWeb, :live_view

  alias Tiki.Accounts
  alias Tiki.Accounts.User

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <div class="mb-6 text-center">
        <h1 class="text-foreground mb-2 text-2xl font-semibold">
          {gettext("Register for an account")}
        </h1>
        <div class="text-muted-foreground text-sm">
          {gettext("Already registered?")}
          <.link navigate={~p"/users/log_in"} class="text-foreground font-semibold hover:underline">
            {gettext("Sign in")}
          </.link>
          {gettext("to your account now.")}
        </div>
      </div>

      <.simple_form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
        <.input
          field={@form[:email]}
          type="email"
          label={gettext("Email")}
          autocomplete="username"
          required
          phx-mounted={JS.focus()}
        />

        <:actions>
          <.button phx-disable-with={gettext("Creating account..")} class="w-full">
            {gettext("Create an account")}
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_email(%User{})

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log_in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           gettext(
             "An email was sent to %{email}. please access it to confirm your account.",
             email: user.email
           )
         )
         |> push_navigate(to: ~p"/users/log_in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_email(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
