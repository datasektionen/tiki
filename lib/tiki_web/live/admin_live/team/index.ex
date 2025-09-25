defmodule TikiWeb.AdminLive.Team.Index do
  use TikiWeb, :live_view

  alias Tiki.Teams

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      {gettext("All teams")}
      <:actions>
        <.link navigate={~p"/admin/teams/new"}>
          <.button>{gettext("New Team")}</.button>
        </.link>
      </:actions>
    </.header>

    <.table
      id="teams"
      rows={@streams.teams}
      row_click={fn {_id, team} -> JS.navigate(~p"/admin/teams/#{team}") end}
    >
      <:col :let={{_id, team}} label={gettext("Name")}>{team.name}</:col>
      <:action :let={{_id, team}}>
        <.link navigate={~p"/admin/teams/#{team}/edit"}>Edit</.link>
      </:action>
      <:action :let={{id, team}}>
        <.link
          phx-click={JS.push("delete", value: %{id: team.id}) |> hide("##{id}")}
          data-confirm={gettext("Are you sure?")}
        >
          Delete
        </.link>
      </:action>
    </.table>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    with :ok <- Tiki.Policy.authorize(:team_view_all, socket.assigns.current_user) do
      {:ok,
       socket
       |> assign(:page_title, gettext("All teams"))
       |> stream(:teams, Teams.list_teams())
       |> assign_breadcrumbs([
         {"Teams", ~p"/admin/teams"}
       ])}
    else
      {:error, :unauthorized} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("You are not authorized to do that."))
         |> redirect(to: ~p"/admin")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    team = Teams.get_team!(id)

    with :ok <- Tiki.Policy.authorize(:team_admin, socket.assigns.current_user, team),
         {:ok, _} = Teams.delete_team(team) do
      {:noreply, stream_delete(socket, :teams, team)}
    else
      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, gettext("You are not authorized to do that."))}
    end
  end
end
