defmodule TikiWeb.AdminLive.Team.MembershipForm do
  alias Tiki.Teams.Membership
  use TikiWeb, :live_view

  alias Tiki.Teams
  alias Tiki.Teams.Membership

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      {@page_title}
      <:subtitle>{gettext("Use this form to manage memberships in your database")}.</:subtitle>
    </.header>

    <.simple_form for={@form} id="team-form" phx-change="validate" phx-submit="save">
      <.live_component
        id="user-select-component"
        module={TikiWeb.LiveComponents.SearchCombobox}
        search_fn={&Tiki.Accounts.search_users/1}
        all_fn={&Tiki.Accounts.list_users/1}
        map_fn={fn user -> {user.id, user.email} end}
        field={@form[:user_id]}
        label={gettext("User")}
        chosen={@form[:user_id].value}
        placeholder={
          Ecto.assoc_loaded?(@form.data.user) && @form[:user].value &&
            @form[:user].value.email
        }
      />
      <.input field={@form[:role]} type="select" label={gettext("Role")} options={[:admin, :member]} />
      <:actions>
        <.button phx-disable-with={gettext("Saving...")}>{gettext("Save")}</.button>
      </:actions>
    </.simple_form>

    <.back navigate={return_path(@return_to)}>
      {gettext("Back")}
    </.back>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    %{current_user: user, current_team: team} = socket.assigns

    with :ok <- Tiki.Policy.authorize(:team_update, user, team) do
      users = Tiki.Accounts.list_users()

      {:ok,
       socket
       |> assign(:users, users)
       |> assign(:return_to, return_to(params["return_to"]))
       |> apply_action(socket.assigns.live_action, params)}
    else
      {:error, :unauthorized} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("You are not authorized to do that."))
         |> redirect(to: ~p"/admin/team/members")}
    end
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    membership = Teams.get_membership!(id)

    socket
    |> assign(:page_title, "Edit Membership")
    |> assign(:membership, membership)
    |> assign(:form, to_form(Teams.change_membership(membership)))
    |> assign_breadcrumbs([
      {"Dashboard", ~p"/admin"},
      {"Team members", ~p"/admin/team/members"},
      {"Edit member", ""}
    ])
  end

  defp apply_action(socket, :new, _params) do
    membership = %Membership{}

    socket
    |> assign(:page_title, gettext("New Membership"))
    |> assign(:membership, membership)
    |> assign(:form, to_form(Teams.change_membership(membership)))
    |> assign_breadcrumbs([
      {"Dashboard", ~p"/admin"},
      {"Team members", ~p"/admin/team/members"},
      {"New member", ~p"/admin/team/members/new"}
    ])
  end

  @impl true
  def handle_event("validate", %{"membership" => membership_params}, socket) do
    changeset = Teams.change_membership(socket.assigns.membership, membership_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  @impl true
  def handle_event("save", %{"membership" => membership_params}, socket) do
    membership_params = Map.put(membership_params, "team_id", socket.assigns.current_team.id)

    save_membership(socket, socket.assigns.live_action, membership_params)
  end

  defp save_membership(socket, :edit, membership_params) do
    case Teams.update_membership(socket.assigns.membership, membership_params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Membership updated successfully"))
         |> push_navigate(to: return_path(socket.assigns.return_to))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_membership(socket, :new, membership_params) do
    case Teams.create_membership(membership_params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Membership created successfully"))
         |> push_navigate(to: return_path(socket.assigns.return_to))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path("index"), do: ~p"/admin/team/members"
  defp return_path("show"), do: ~p"/admin/team/members"
end
