defmodule TikiWeb.AdminLive.Dashboard.Team do
  use TikiWeb, :live_view

  alias Tiki.Teams
  import TikiWeb.Component.Card
  import TikiWeb.Component.Select

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.header>
      {@page_title}
      <:subtitle>
        {gettext("No team selected")}
      </:subtitle>
    </.header>

    <div class="mt-4 gap-4">
      <.card class="">
        <.card_header>
          <.card_title>
            {gettext("No team selected")}
          </.card_title>
          <.card_description>
            {gettext("Please select a team to get started.")}
          </.card_description>
        </.card_header>
        <.card_content>
          <.form for={%{}} phx-change="select">
            <.select
              :let={select}
              name="team"
              id="team-select"
              target="team-select"
              placeholder={gettext("Select a team")}
              class="w-full"
            >
              <.select_trigger builder={select} />
              <.select_content builder={select} class="w-full">
                <.select_group>
                  <.select_label>{gettext("Teams")}</.select_label>

                  <.select_item
                    :for={team <- @teams}
                    builder={select}
                    value={team.id}
                    label={team.name}
                  >
                    {team.name}
                  </.select_item>
                </.select_group>
              </.select_content>
            </.select>
          </.form>
        </.card_content>
      </.card>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if socket.assigns.current_team do
      {:ok, redirect(socket, to: ~p"/admin")}
    else
      teams = Teams.get_teams_for_user(socket.assigns.current_user.id)

      {:ok,
       socket
       |> assign(:teams, teams)
       |> assign(:page_title, gettext("Select team"))
       |> assign_breadcrumbs([
         {"Dashboard", ~p"/admin"}
       ])}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("select", %{"team" => id}, socket) do
    {:noreply, redirect(socket, to: ~p"/admin/set_team/#{id}")}
  end
end
