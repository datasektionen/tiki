defmodule TikiWeb.AdminLive.Team.Show do
  use TikiWeb, :live_view

  on_mount {TikiWeb.UserAuth, {:authorize, :team_admin}}

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.header>
      {@page_title}
      <:subtitle>{gettext("Manage memberships for your team.")}</:subtitle>
      <:actions>
        <.link navigate={~p"/admin/teams/#{@team}/members/new?return_to=show"}>
          <.button>{gettext("Add member")}</.button>
        </.link>
      </:actions>
    </.header>

    <.table id="members" rows={@streams.members}>
      <:col :let={{_id, membership}} label={gettext("Name")}>{membership.user.full_name}</:col>
      <:col :let={{_id, membership}} label={gettext("Email")}>{membership.user.email}</:col>
      <:col :let={{_id, membership}} label={gettext("Role")}>{membership.role}</:col>

      <:action :let={{_id, membership}}>
        <.link navigate={~p"/admin/teams/#{@team}/members/#{membership}/edit?return_to=show"}>
          {gettext("Edit")}
        </.link>
      </:action>
      <:action :let={{id, membership}}>
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

  @impl Phoenix.LiveView
  def mount(%{"id" => id}, _session, socket) do
    team = Tiki.Teams.get_team!(id)
    members = Tiki.Teams.get_members_for_team(id)

    {:ok,
     assign(socket, team: team)
     |> assign(:page_title, team.name)
     |> stream(:members, members)
     |> assign_breadcrumbs([
       {"Teams", ~p"/admin/teams"},
       {team.name, ~p"/admin/teams/#{team.id}"}
     ])}
  end

  @impl Phoenix.LiveView
  def handle_event("delete", %{"id" => id}, socket) do
    %{current_user: user, team: team} = socket.assigns

    with :ok <- Tiki.Policy.authorize(:team_update, user, team) do
      membership = Tiki.Teams.get_membership!(id)

      {:ok, _} = Tiki.Teams.delete_membership(membership)

      {:noreply, stream_delete(socket, :members, membership)}
    else
      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, gettext("You are not authorized to do that."))}
    end
  end
end
