defmodule TikiWeb.AdminLive.Users.FormComponent do
  use TikiWeb, :live_component

  alias Tiki.Accounts
  alias Phoenix.LiveView.Socket
  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {title(@action)}
        <:subtitle>
          <%= if @action == :edit do %>
            {gettext("Edit user details for %{email}", email: @user.email)}
          <% else %>
            {gettext("Create a new user account")}
          <% end %>
        </:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="user-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:email]} type="email" label={gettext("Email")} required />
        <.input field={@form[:first_name]} type="text" label={gettext("First Name")} />
        <.input field={@form[:last_name]} type="text" label={gettext("Last Name")} />
        <.input field={@form[:kth_id]} type="text" label={gettext("KTH ID")} />
        <.input field={@form[:year_tag]} type="text" label={gettext("Year Tag")} />
        <.input
          field={@form[:locale]}
          type="select"
          label={gettext("Locale")}
          options={[
            {"English", "en"},
            {"Swedish", "sv"}
          ]}
        />
        <.input
          :if={@action == :edit}
          field={@form[:confirmed_at]}
          type="datetime-local"
          label={gettext("Confirmed At")}
          description={gettext("Leave empty for unconfirmed accounts")}
        />

        <div :if={is_list(@user.memberships)} class="mt-4">
          <div class="mt-4">
            <label class="font-medium leading-none text-sm">
              {gettext("Teams")}
            </label>
            <div class="mt-1">
              <div :for={membership <- @user.memberships || []} class="mt-2 flex items-center gap-2">
                <span class="text-sm">{membership.team.name}</span>
                <span class="text-xs text-muted-foreground">({membership.role})</span>
              </div>
              <div
                :if={@user.memberships == [] || @user.memberships == nil}
                class="mt-1 text-sm text-muted-foreground"
              >
                {gettext("No team memberships")}
              </div>
              <p class="mt-1 text-xs text-muted-foreground">
                {gettext("Team memberships must be managed from the Teams section")}
              </p>
            </div>
          </div>
        </div>


        <div class="flex flex-row gap-4">
        <div :if={@action == :edit} >
            <.button
              type="button"
              phx-click="delete_user"
              phx-target={@myself}
              class="bg-destructive hover:bg-destructive/90"
              data-confirm={
                gettext("Are you sure you want to delete this user? This action cannot be undone.")
              }
            >
              {gettext("Delete User")}
            </.button>
        </div>
          <.button phx-disable-with={gettext("Saving...")}>
            {gettext("Save User")}
          </.button>
        </div>
      </.simple_form>

      <div class="flex flex-col gap-2 mt-4">
      <p class="font-medium leading-none text-sm">{gettext("Admin Tools")}</p>

      <.form
        :if={@user.id}
        for={%{}}
        id="assume-user-form"
        action={~p"/users/hijack"}
        method="post"
      >
        <.input name="user_id" value={@user.id} type="hidden" />
        <.button phx-disable-with={gettext("Confirming...")} >
          {gettext("Assume User Identity")}
        </.button>
        <p class="mt-2 text-xs text-muted-foreground">
          {gettext(
            "This will log you in as this user for debugging purposes."
          )}
        </p>
      </.form>
      </div>

    </div>
    """
  end

  @impl true
  def update(%{user: user} = assigns, socket) do
    # Always preload memberships for existing users
    user =
      if user.id do
        Tiki.Repo.preload(user, memberships: :team)
      else
        user
      end

    form = to_form(user_changeset(user))

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, form)
     |> assign(:user, user)}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    form =
      socket.assigns.user
      |> user_changeset(user_params)
      |> to_form()

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    save_user(socket, socket.assigns.action, user_params)
  end

  def handle_event("delete_user", _, socket) do
    case Accounts.delete_user(socket.assigns.user) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("User deleted successfully"))
         |> push_navigate(to: ~p"/admin/users")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Error deleting user"))
         |> assign(form: to_form(changeset))}
    end
  end

  def handle_event("assume_user", %{"user_id" => user_id}, socket) do
    params = %{
      "user_id" => user_id
    }

    {:noreply, push_navigate(socket, to: ~p"/users/hijack?#{params}")}
  end

  defp save_user(socket, :edit, user_params) do
    # Convert the confirmed_at datetime string to NaiveDateTime if present
    user_params = maybe_convert_confirmed_at(user_params)

    case Accounts.admin_update_user(socket.assigns.user, user_params) do
      {:ok, user} ->
        # Reload the user with associations
        user = Tiki.Repo.preload(user, memberships: :team)
        notify_parent({:saved, user})

        {:noreply,
         socket
         |> put_flash(:info, gettext("User updated successfully"))
         |> push_navigate(to: ~p"/admin/users")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp maybe_convert_confirmed_at(%{"confirmed_at" => ""} = params) do
    # Handle empty string by setting confirmed_at to nil (unconfirmed account)
    Map.put(params, "confirmed_at", nil)
  end

  defp maybe_convert_confirmed_at(%{"confirmed_at" => confirmed_at} = params)
       when is_binary(confirmed_at) do
    # Convert from string to NaiveDateTime
    case NaiveDateTime.from_iso8601(confirmed_at) do
      {:ok, dt} -> Map.put(params, "confirmed_at", dt)
      _ -> params
    end
  end

  defp maybe_convert_confirmed_at(params), do: params

  defp save_user(socket, :new, user_params) do
    # Convert the confirmed_at datetime string to NaiveDateTime if present
    user_params = maybe_convert_confirmed_at(user_params)

    case Accounts.register_user(user_params) do
      {:ok, user} ->
        # Automatically confirm the user if confirmed_at is provided
        user =
          if Map.get(user_params, "confirmed_at") do
            {:ok, confirmed_user} =
              Accounts.admin_update_user(user, %{
                "confirmed_at" => Map.get(user_params, "confirmed_at")
              })

            confirmed_user
          else
            user
          end

        notify_parent({:saved, user})

        {:noreply,
         socket
         |> put_flash(:info, gettext("User created successfully"))
         |> push_navigate(to: ~p"/admin/users")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp user_changeset(user, attrs \\ %{}) do
    changeset =
      case user.id do
        nil ->
          # For new users
          Accounts.change_user_email(user, attrs)

        _ ->
          # For existing users - use a more permissive changeset for admins
          user
          |> Ecto.Changeset.cast(attrs, [
            :email,
            :first_name,
            :last_name,
            :kth_id,
            :year_tag,
            :confirmed_at,
            :locale
          ])
          |> Ecto.Changeset.validate_required([:email])
      end

    # Ensure we properly load the memberships
    user = if user.id, do: Tiki.Repo.preload(user, memberships: :team), else: user

    %{changeset | data: user}
  end

  defp title(:new), do: gettext("New User")
  defp title(:edit), do: gettext("Edit User")
end
