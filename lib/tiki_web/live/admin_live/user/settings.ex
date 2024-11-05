defmodule TikiWeb.AdminLive.User.Settings do
  use TikiWeb, :live_view

  alias Tiki.Accounts
  import TikiWeb.Component.Card

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_data(socket.assigns.current_user, %{})

    {:ok, assign(socket, form: to_form(changeset))}
  end

  def handle_params(_params, url, socket) do
    {:noreply, assign_breadcrumbs(socket, [{"User settings", url}])}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_data(socket.assigns.current_user, user_params)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.update_user_data(socket.assigns.current_user, user_params) do
      {:ok, user} ->
        Gettext.put_locale(TikiWeb.Gettext, user.locale)
        Cldr.put_locale(Tiki.Cldr, user.locale)

        {:noreply,
         socket
         |> put_flash(:info, gettext("User settings updated"))
         |> redirect(to: "/admin")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="sm:max-w-3xl">
      <div class="flex flex-col gap-1 border-b pb-4">
        <.card_title>
          <%= gettext("User settings") %>
        </.card_title>
        <.card_description>
          <%= gettext("Modify user settings") %>
        </.card_description>
      </div>
      <.form for={@form} class="flex flex-col gap-2 pt-6" phx-change="validate" phx-submit="save">
        <.input field={@form[:first_name]} label={gettext("First name")} />
        <.input field={@form[:last_name]} label={gettext("Last name")} />
        <.input
          field={@form[:locale]}
          label={gettext("Prefered language")}
          type="select"
          options={[{"English", "en"}, {"Svenska", "sv"}]}
        />
        <div class="mt-4">
          <.button type="submit">
            <%= gettext("Save") %>
          </.button>
        </div>
      </.form>
    </div>
    """
  end
end
