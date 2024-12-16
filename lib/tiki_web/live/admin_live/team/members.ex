defmodule TikiWeb.AdminLive.Team.Members do
  use TikiWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    %{current_user: user, current_team: team} = socket.assigns

    with :ok <- Tiki.Policy.authorize(:team_read, user, team) do
      members = Tiki.Teams.get_members_for_team(socket.assigns.current_team.id)
      allowed_update? = Tiki.Policy.authorize?(:team_update, user, team)

      {:ok, assign(socket, allowed_update?: allowed_update?) |> stream(:members, members)}
    else
      {:error, :unauthorized} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("You are not authorized to do that."))
         |> redirect(to: ~p"/admin")}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _url, socket) do
    {:noreply,
     assign_breadcrumbs(
       socket,
       [{"Dashboard", ~p"/admin"}, {"Team members", ~p"/admin/team/members"}]
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("delete", %{"id" => id}, socket) do
    %{current_user: user, current_team: team} = socket.assigns

    with :ok <- Tiki.Policy.authorize(:team_update, user, team) |> dbg() do
      membership = Tiki.Teams.get_membership!(id)

      {:ok, _} = Tiki.Teams.delete_membership(membership)

      {:noreply, stream_delete(socket, :members, membership)}
    else
      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, gettext("You are not authorized to do that."))}
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.header>
      {gettext("Team members")}
      <:actions>
        <.link navigate={~p"/admin/team/members/new"}>
          <.button>{gettext("Add member")}</.button>
        </.link>
      </:actions>
    </.header>
    <.table id="members" rows={@streams.members}>
      <:col :let={{_id, membership}} label={gettext("Name")}>{membership.user.full_name}</:col>
      <:col :let={{_id, membership}} label={gettext("Email")}>{membership.user.email}</:col>
      <:col :let={{_id, membership}} label={gettext("Role")}>{membership.role}</:col>

      <:action :let={{_id, membership}} :if={@allowed_update?}>
        <.link navigate={~p"/admin/team/members/#{membership}/edit"}>
          {gettext("Edit")}
        </.link>
      </:action>
      <:action :let={{id, membership}} :if={@allowed_update?}>
        <.link
          phx-click={JS.push("delete", value: %{id: membership.id}) |> hide("##{id}")}
          data-confirm={gettext("Are you sure?")}
        >
          {gettext("Delete")}
        </.link>
      </:action>
    </.table>
    """
  end
end
