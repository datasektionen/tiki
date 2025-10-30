defmodule TikiWeb.AdminLive.Dashboard.Index do
  use TikiWeb, :live_view

  alias Tiki.Events
  alias Tiki.Orders
  alias Tiki.Policy
  alias Tiki.Localizer

  import TikiWeb.Component.Card

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    %{current_user: user, current_team: team} = socket.assigns

    with :ok <- Policy.authorize(:event_view, user, team) do
      events =
        Events.list_team_events(team.id)
        |> Localizer.localize()

      stats = Tiki.Teams.get_team_stats!(team.id)

      recent_tickets =
        Orders.list_team_orders(team.id, limit: 10, status: [:paid])
        |> Enum.flat_map(fn order ->
          Enum.map(order.tickets, fn ticket ->
            Map.put(ticket, :order, order)
          end)
        end)

      {:ok,
       socket
       |> stream(:events, events)
       |> stream(:recent_tickets, recent_tickets)
       |> assign(:stats, stats)
       |> assign(:page_title, gettext("Dashboard"))
       |> assign_breadcrumbs([
         {"Dashboard", ~p"/admin"}
       ])}
    else
      {:error, :unauthorized} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("You are not authorized to do that."))
         |> redirect(to: ~p"/admin/clear_team")}
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
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
            <div class="text-2xl font-bold">{@stats.total_events}</div>
            <p class="text-muted-foreground text-xs">
              +{@stats.total_events - @stats.last_month.total_events} {gettext("from last month")}
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
            <div class="text-2xl font-bold">{@stats.tickets_sold}</div>
            <p class="text-muted-foreground text-xs">
              +{Decimal.sub(@stats.tickets_sold, @stats.last_month.tickets_sold)} {gettext(
                "from last month"
              )}
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
            <div class="text-2xl font-bold">
              {sold_per_event(@stats)}
            </div>
            <p class="text-muted-foreground text-xs">
              +{sold_per_event(@stats)
              |> Decimal.sub(sold_per_event(@stats.last_month))
              |> Decimal.round(0, :down)} {gettext("from last month")}
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
            <div class="text-2xl font-bold">{format_sek(@stats.total_sales)}</div>
            <p class="text-muted-foreground text-xs">
              +{(@stats.total_sales - @stats.last_month.total_sales) |> format_sek()} {gettext(
                "from last month"
              )}
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
                {Calendar.strftime(event.start_time, "%Y-%m-%d")}
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
              id="attendees"
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
                {Localizer.localize(ticket.order.event).name}
              </:col>
              <:col :let={{_id, ticket}} label={gettext("Date")}>
                {Calendar.strftime(ticket.inserted_at, "%Y-%m-%d")}
              </:col>
            </.table>
          </.card_content>
        </.card>
      </div>
    </div>
    """
  end

  defp sold_per_event(stats) do
    case stats.total_events do
      0 -> 0
      _ -> Decimal.div_int(stats.tickets_sold, stats.total_events)
    end
  end
end
