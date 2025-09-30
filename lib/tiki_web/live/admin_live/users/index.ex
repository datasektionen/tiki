defmodule TikiWeb.AdminLive.Users.Index do
  use TikiWeb, :live_view

  alias Tiki.Accounts

  import TikiWeb.Component.Sheet
  import TikiWeb.Component.Badge

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.header>
      {gettext("Users")}
      <:subtitle>
        {gettext("Manage user accounts.")}
      </:subtitle>
      <:actions>
        <.link patch={~p"/admin/users/new"}>
          <.button>{gettext("New User")}</.button>
        </.link>
      </:actions>
    </.header>

    <div class="mb-8">
      <.form for={@search_form} id="search-form" phx-change="search" class="max-w-md">
        <div class="flex flex-col gap-4 sm:flex-row">
          <div class="flex-1">
            <.input
              field={@search_form[:query]}
              type="search"
              placeholder={gettext("Search by email, name...")}
            />
          </div>
        </div>
      </.form>
    </div>

    <div class="overflow-x-auto">
      <.table
        id="users"
        rows={@streams.users}
        row_click={fn {_id, user} -> JS.navigate(~p"/admin/users/#{user.id}/edit") end}
      >
        <:col :let={{_id, user}} label={gettext("Email")}>{user.email}</:col>
        <:col :let={{_id, user}} label={gettext("Name")}>
          <%= if user.first_name || user.last_name do %>
            {[user.first_name, user.last_name] |> Enum.reject(&is_nil/1) |> Enum.join(" ")}
          <% end %>
        </:col>
        <:col :let={{_id, user}} label={gettext("KTH ID")}>{user.kth_id}</:col>
        <:col :let={{_id, user}} label={gettext("Status")}>
          <.badge :if={user.confirmed_at} variant="success">
            {gettext("Confirmed")}
          </.badge>
          <.badge :if={!user.confirmed_at} variant="warning">
            {gettext("Unconfirmed")}
          </.badge>
        </:col>
        <:col :let={{_id, user}} label={gettext("Created")}>
          {Calendar.strftime(user.inserted_at, "%Y-%m-%d")}
        </:col>

        <:action :let={{_id, user}}>
          <.link navigate={~p"/admin/users/#{user.id}/edit"}>
            {gettext("Edit")}
          </.link>
        </:action>
      </.table>
    </div>

    <.sheet :if={@live_action in [:edit, :new]} class="">
      <.sheet_content
        show
        id="user-form-sheet"
        side="right"
        class="w-full"
        on_cancel={JS.navigate(~p"/admin/users")}
      >
        <.live_component
          id="user-form-component"
          module={TikiWeb.AdminLive.Users.FormComponent}
          user={@user}
          action={@live_action}
          current_user={@current_user}
        />
      </.sheet_content>
    </.sheet>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    with :ok <- Tiki.Policy.authorize(:tiki_admin, socket.assigns.current_user) do
      users = Accounts.list_users()
      search_form = to_form(%{"query" => ""})

      {:ok,
       socket
       |> assign(:search_form, search_form)
       |> stream(:users, users)}
    else
      {:error, :unauthorized} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("You are not authorized to do that."))
         |> redirect(to: ~p"/admin")}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(params, _session, socket) do
    {:noreply,
     socket
     |> assign_breadcrumbs([
       {"Dashboard", ~p"/admin"},
       {"Users", ~p"/admin/users"}
     ])
     |> apply_action(socket.assigns.live_action, params)}
  end

  def apply_action(socket, :index, _params), do: assign(socket, :page_title, gettext("Users"))

  def apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, gettext("New User"))
    |> assign(:user, %Tiki.Accounts.User{})
  end

  def apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, gettext("Edit User"))
    |> assign(:user, Accounts.get_user!(id))
  end

  @impl true
  def handle_info({TikiWeb.AdminLive.Users.FormComponent, {:saved, user}}, socket) do
    {:noreply, stream_insert(socket, :users, user)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    search_form = to_form(%{"query" => query})

    # Get initial list of users based on search query
    users =
      if query && query != "" do
        Accounts.search_users(query)
      else
        Accounts.list_users()
      end

    {:noreply,
     socket
     |> assign(:search_form, search_form)
     |> stream(:users, users, reset: true)}
  end
end
