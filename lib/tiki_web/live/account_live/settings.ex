defmodule TikiWeb.AccountLive.Settings do
  use TikiWeb, :live_view

  alias Tiki.Accounts

  def render(assigns) do
    ~H"""
    <.header class="text-center">
      {gettext("Account Settings")}
      <:subtitle>
        {gettext("Manage your account settings and set your preferred language.")}
      </:subtitle>
    </.header>

    <div>
      <.simple_form
        for={@email_form}
        id="email_form"
        phx-submit="update_email"
        phx-change="validate_email"
      >
        <.input field={@email_form[:email]} type="email" label={gettext("Email")} required />

        <:actions>
          <.button phx-disable-with={gettext("Changing...")}>{gettext("Change Email")}</.button>
        </:actions>
      </.simple_form>
    </div>
    <div>
      <.simple_form
        for={@user_form}
        class="flex flex-col gap-2 pt-6"
        phx-submit="update_user"
        phx-change="validate_user"
      >
        <.input field={@user_form[:first_name]} label={gettext("First name")} />
        <.input field={@user_form[:last_name]} label={gettext("Last name")} />
        <.input
          field={@user_form[:locale]}
          label={gettext("Prefered language")}
          type="select"
          options={[{"English", "en"}, {"Svenska", "sv"}]}
        />
        <div class="mt-4">
          <.button type="submit">
            {gettext("Save")}
          </.button>
        </div>
      </.simple_form>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_user, token) do
        :ok ->
          put_flash(socket, :info, gettext("Email changed successfully."))

        :error ->
          put_flash(socket, :error, gettext("Email change link is invalid or it has expired."))
      end

    {:ok, push_navigate(socket, to: ~p"/account/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    email_changeset = Accounts.change_user_email(user)
    user_changeset = Accounts.change_user_data(user)

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:user_form, to_form(user_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  def handle_event("validate_user", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_data(socket.assigns.current_user, user_params)

    {:noreply, assign(socket, user_form: to_form(changeset))}
  end

  def handle_event("update_user", %{"user" => user_params}, socket) do
    case Accounts.update_user_data(socket.assigns.current_user, user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("User settings updated"))
         |> redirect(to: ~p"/account/settings")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_user
      |> Accounts.change_user_email(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/account/settings/confirm_email/#{&1}")
        )

        info = gettext("A link to confirm your email change has been sent to the new address.")
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end
end
