defmodule TikiWeb.AdminLive.Team.Show do
  use TikiWeb, :live_view

  alias Tiki.Teams

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Team {@team.id}
      <:subtitle>This is a team record from your database.</:subtitle>
      <:actions>
        <.link navigate={~p"/admin/teams/#{@team}/edit?return_to=show"}>
          <.button>Edit team</.button>
        </.link>
      </:actions>
    </.header>

    <.list>
      <:item title="Name">{@team.name}</:item>
    </.list>

    <.back navigate={~p"/admin/teams"}>Back to teams</.back>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, "Show Team")
     |> assign(:team, Teams.get_team!(id))}
  end
end
