defmodule TikiWeb.AdminLive.Team.Index do
  use TikiWeb, :live_view

  alias Tiki.Teams

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Listing Teams
      <:actions>
        <.link navigate={~p"/admin/teams/new"}>
          <.button>New Team</.button>
        </.link>
      </:actions>
    </.header>

    <.table id="teams" rows={@streams.teams}>
      <:col :let={{_id, team}} label="Name">{team.name}</:col>
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
    with :ok <- Tiki.Policy.authorize(:team_admin, socket.assigns.current_user) do
      {:ok,
       socket
       |> assign(:page_title, "Listing Teams")
       |> stream(:teams, Teams.list_teams())}
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
    {:ok, _} = Teams.delete_team(team)

    {:noreply, stream_delete(socket, :teams, team)}
  end
end
