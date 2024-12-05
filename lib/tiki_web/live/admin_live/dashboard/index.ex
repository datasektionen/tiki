defmodule TikiWeb.AdminLive.Dashboard.Index do
  use TikiWeb, :live_view

  alias Tiki.Teams
  alias Tiki.Events
  alias Tiki.Orders

  import TikiWeb.Component.Card
  import TikiWeb.Component.Select

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, assign_data(socket, socket.assigns.current_team)}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, gettext("Dashboard"))
    |> assign_breadcrumbs([
      {"Dashboard", ~p"/admin"}
    ])
  end

  defp assign_data(socket, nil) do
    teams = Teams.get_teams_for_user(socket.assigns.current_user.id)

    assign(socket, :teams, teams)
  end

  defp assign_data(socket, team) do
    events = Events.list_team_events(team.id)

    recent_tickets =
      Orders.list_team_orders(team.id, limit: 10, status: [:paid])
      |> Enum.flat_map(fn order ->
        Enum.map(order.tickets, fn ticket ->
          Map.put(ticket, :order, order)
        end)
      end)

    socket
    |> stream(:events, events)
    |> stream(:recent_tickets, recent_tickets)
  end

  @impl Phoenix.LiveView
  def handle_event("select", %{"team" => id}, socket) do
    {:noreply, redirect(socket, to: ~p"/admin/set_team/#{id}")}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div :if={!@current_team}>
      <.header>
        {@page_title}
        <:subtitle>
          {gettext("No team selected")}
        </:subtitle>
      </.header>

      <div class="mt-4 grid grid-cols-6 gap-4">
        <.card class="col-span-6 sm:col-span-2">
          <.card_header>
            <.card_title>
              {gettext("Welcome")}
            </.card_title>
          </.card_header>
          <.card_content>
            {"#{gettext("Hi")}, #{@current_user.first_name}! #{gettext("Welcome back to Tiki!")}"}
          </.card_content>
        </.card>
        <.card class="col-span-6 sm:col-span-4">
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
    </div>

    <div :if={@current_team}>
      <div class="flex flex-col gap-8">
        <div class="grid gap-8 md:grid-cols-2 xl:grid-cols-4">
          <.card>
            <.card_header class="flex flex-row items-center justify-between space-y-0 pb-2">
              <.card_title class="text-sm font-medium">
                {gettext("Total events")}
              </.card_title>
              <.icon name="hero-calendar" class="text-muted-foreground h-4 w-4" />
            </.card_header>
            <.card_content>
              <div class="text-2xl font-bold">N/A</div>
              <p class="text-muted-foreground text-xs">
                +N/A {gettext("from last month")}
              </p>
            </.card_content>
          </.card>
          <.card>
            <.card_header class="flex flex-row items-center justify-between space-y-0 pb-2">
              <.card_title class="text-sm font-medium">
                {gettext("Tickets sold")}
              </.card_title>
              <.icon name="hero-ticket" class="text-muted-foreground h-4 w-4" />
            </.card_header>
            <.card_content>
              <div class="text-2xl font-bold">N/A</div>
              <p class="text-muted-foreground text-xs">
                +N/A {gettext("from last month")}
              </p>
            </.card_content>
          </.card>
          <.card>
            <.card_header class="flex flex-row items-center justify-between space-y-0 pb-2">
              <.card_title class="text-sm font-medium">
                {gettext("Tickets sold per event")}
              </.card_title>
              <.icon name="hero-banknotes" class="text-muted-foreground h-4 w-4" />
            </.card_header>
            <.card_content>
              <div class="text-2xl font-bold">N/A</div>
              <p class="text-muted-foreground text-xs">
                +N/A {gettext("from last month")}
              </p>
            </.card_content>
          </.card>
          <.card>
            <.card_header class="flex flex-row items-center justify-between space-y-0 pb-2">
              <.card_title class="text-sm font-medium">
                {gettext("Total sales")}
              </.card_title>
              <.icon name="hero-ticket" class="text-muted-foreground h-4 w-4" />
            </.card_header>
            <.card_content>
              <div class="text-2xl font-bold">N/A</div>
              <p class="text-muted-foreground text-xs">
                +N/A {gettext("from last month")}
              </p>
            </.card_content>
          </.card>
        </div>
        <div class="grid gap-4 xl:grid-cols-7">
          <.card class="xl:col-span-4">
            <.card_header>
              <div class="flex flex-row items-center justify-between">
                <div>
                  <.card_title>
                    {gettext("Events")}
                  </.card_title>
                  <.card_description class="pt-1">
                    {gettext("All events for %{team}", team: @current_team.name)}
                  </.card_description>
                </div>

                <.button navigate={~p"/admin/events/new"} variant="outline" size="icon">
                  <span class="sr-only">{gettext("New event")}</span>
                  <.icon name="hero-plus-mini" class="h-4 w-4" />
                </.button>
              </div>
            </.card_header>
            <.card_content>
              <.table
                id="events"
                rows={@streams.events}
                row_click={fn {_id, event} -> JS.navigate(~p"/admin/events/#{event}") end}
              >
                <:col :let={{_id, event}} label={gettext("Name")}>{event.name}</:col>
                <:col :let={{_id, event}} label={gettext("Location")}>{event.location}</:col>
                <:col :let={{_id, event}} label={gettext("Date")}>
                  {Calendar.strftime(event.event_date, "%Y-%m-%d")}
                </:col>
              </.table>
            </.card_content>
          </.card>
          <.card class="xl:col-span-3">
            <.card_header>
              <.card_title>
                {gettext("Recent orders")}
              </.card_title>
            </.card_header>
            <.card_content>
              <.table
                id="events"
                rows={@streams.recent_tickets}
                row_click={
                  fn {_id, ticket} ->
                    JS.navigate(~p"/admin/events/#{ticket.order.event}/attendees/#{ticket}")
                  end
                }
              >
                <:col :let={{_id, ticket}} label={gettext("Name")}>
                  {ticket.order.user.full_name}
                </:col>
                <:col :let={{_id, ticket}} label={gettext("Event")}>
                  {ticket.order.event.name}
                </:col>
                <:col :let={{_id, ticket}} label={gettext("Date")}>
                  {Calendar.strftime(ticket.inserted_at, "%Y-%m-%d")}
                </:col>
              </.table>
            </.card_content>
          </.card>
        </div>
      </div>
    </div>
    """
  end
end
