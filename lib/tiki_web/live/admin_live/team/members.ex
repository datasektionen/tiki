defmodule TikiWeb.AdminLive.Team.Members do
  use TikiWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    members = Tiki.Teams.get_members_for_team(socket.assigns.current_team.id)

    {:ok, stream(socket, :members, members)}
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
    membership = Tiki.Teams.get_membership!(id)

    {:ok, _} = Tiki.Teams.delete_membership(membership)

    {:noreply, stream_delete(socket, :members, membership)}
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

      <:action :let={{_id, membership}}>
        <.link navigate={~p"/admin/team/members/#{membership}/edit"}>
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
end
