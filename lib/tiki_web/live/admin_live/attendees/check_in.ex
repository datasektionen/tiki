defmodule TikiWeb.AdminLive.Attendees.CheckIn do
  use TikiWeb, :live_view

  alias Tiki.Events
  alias Tiki.Orders
  alias Tiki.Tickets
  alias Tiki.Localizer

  import TikiWeb.Component.Card
  import TikiWeb.Component.Badge
  import TikiWeb.Component.Input
  import TikiWeb.Component.Tabs
  import TikiWeb.Component.Sheet
  import TikiWeb.Component.Skeleton

  @page_size 50

  def mount(%{"event_id" => event_id}, _session, socket) do
    event =
      Events.get_event!(event_id)
      |> Localizer.localize()

    with :ok <- Tiki.Policy.authorize(:event_view, socket.assigns.current_user, event) do
      %{entries: tickets, metadata: metadata} =
        Orders.list_tickets_for_event(event_id, limit: @page_size, paginate: %{after: nil})

      ticket_types =
        Tickets.get_cached_available_ticket_types(event_id)
        |> Localizer.localize()
        |> Enum.map(&{&1.name, &1.id})

      if connected?(socket) do
        Orders.PubSub.subscribe_to_ticket_checkins(event_id)
      end

      {:ok,
       socket
       |> assign(event: event)
       |> assign(page_title: gettext("Check-in"))
       |> assign(query: nil, filtered_ticket_type: nil)
       |> assign(:ticket_types, ticket_types)
       |> assign(:empty?, Enum.empty?(tickets))
       |> assign(:ticket, nil)
       |> assign(:metadata, metadata)
       |> stream(:tickets, tickets)
       |> assign_breadcrumbs([
         {"Dashboard", ~p"/admin/"},
         {"Events", ~p"/admin/events"},
         {event.name, ~p"/admin/events/#{event.id}"},
         {"Check-in", ~p"/admin/events/#{event.id}/check-in"}
       ])}
    else
      {:error, :unauthorized} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("You are not authorized to do that."))
         |> redirect(to: ~p"/admin")}
    end
  end

  def handle_event("filter", %{"query" => query, "filter" => filter}, socket) do
    %{entries: tickets, metadata: metadata} =
      Orders.list_tickets_for_event(socket.assigns.event.id,
        query: query,
        ticket_type: filter,
        limit: @page_size,
        paginate: %{after: nil}
      )

    {:noreply,
     assign(socket, query: query, filtered_ticket_type: filter)
     |> stream(:tickets, tickets, reset: true)
     |> assign(:metadata, metadata)
     |> assign(:empty?, Enum.empty?(tickets))}
  end

  def handle_event("check_in", %{"ticket_id" => ticket_id, "check_out" => false}, socket),
    do: toggle_check_in(socket, ticket_id, check_out: false)

  def handle_event("check_in", %{"ticket_id" => ticket_id}, socket),
    do: toggle_check_in(socket, ticket_id)

  def handle_event("select_ticket", %{"ticket_id" => ticket_id}, socket) do
    ticket = Orders.get_ticket!(ticket_id)

    {:noreply, assign(socket, ticket: ticket)}
  end

  def handle_event("clear_ticket", _params, socket) do
    {:noreply, assign(socket, ticket: nil)}
  end

  def handle_event("load_more", _, socket) do
    %{entries: tickets, metadata: metadata} =
      Orders.list_tickets_for_event(socket.assigns.event.id,
        query: socket.assigns.query,
        limit: @page_size,
        paginate: %{after: socket.assigns.metadata.after}
      )

    {:noreply, assign(socket, metadata: metadata) |> stream(:tickets, tickets)}
  end

  defp toggle_check_in(socket, ticket_id, opts \\ []) do
    with :ok <-
           Tiki.Policy.authorize(:event_manage, socket.assigns.current_user, socket.assigns.event),
         {:ok, ticket} <- Orders.toggle_check_in(socket.assigns.event.id, ticket_id, opts) do
      {:noreply,
       stream_insert(socket, :tickets, ticket)
       |> then(fn socket ->
         if Keyword.get(opts, :check_out, true),
           do: socket,
           else: put_flash(socket, :info, gettext("Checked in: %{name}", name: ticket.name))
       end)}
    else
      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, gettext("You are not authorized to do that."))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, reason)}
    end
  end

  def render(assigns) do
    ~H"""
    <div>
      <.card_title class="sm:col-span-6">
        {gettext("Check-in")}
      </.card_title>
      <p class="text-muted-foreground text-sm">
        {gettext(
          "Manage check-in for your event. You can either use the table to manually check in users, or scan the qr-code on their ticket. To scan, you need to allow the website to use your camera."
        )}
      </p>

      <.tabs :let={builder} default="table" id="tab" class="mt-4">
        <.tabs_list class="grid max-w-xl grid-cols-2">
          <.tabs_trigger builder={builder} value="table">{gettext("Table")}</.tabs_trigger>
          <.tabs_trigger builder={builder} value="scanner">{gettext("Scanner")}</.tabs_trigger>
        </.tabs_list>

        <.tabs_content value="table" class="mt-4">
          <div class="grid gap-4 sm:grid-cols-6">
            <.form
              for={%{}}
              phx-change="filter"
              class="flex flex-row items-center gap-2 sm:col-span-6"
            >
              <.leading_logo_input
                name="query"
                value={@query}
                type="text"
                phx-debounce="300"
                placeholder={gettext("Search")}
                class="max-w-xl flex-1"
              />

              <div class="ml-auto">
                <.simple_select
                  id="filter"
                  name="filter"
                  options={@ticket_types}
                  prompt={gettext("Ticket type")}
                  value={@filtered_ticket_type}
                />
              </div>
            </.form>

            <.card class=" sm:col-span-6">
              <li
                :if={@empty?}
                class="inline-flex cursor-pointer items-center justify-between gap-x-2 p-4 first:rounded-t-xl last:rounded-b-xl sm:px-4 lg:px-6"
              >
                <.icon name="hero-ticket-mini" class="size-4" />
                <span class="text-sm">
                  {gettext("No tickets")}
                </span>
              </li>
              <ul
                id="tickets"
                role="list"
                phx-update="stream"
                class="divide-accent divide-y"
                phx-viewport-bottom={(!@query || @query == "") && JS.push("load_more")}
              >
                <.ticket_item :for={{id, ticket} <- @streams.tickets} ticket={ticket} id={id} />
              </ul>
            </.card>
          </div>
        </.tabs_content>
        <.tabs_content value="scanner" class="mt-4">
          <.button
            id="start_scan"
            phx-click={JS.dispatch("start_scan", to: "#video") |> JS.hide(to: "#start_scan")}
          >
            {gettext("Start Scan")}
          </.button>
          <video id="video" phx-hook="Scanner" class="h-full w-full rounded-xl"></video>
        </.tabs_content>

        <.sheet>
          <.sheet_content
            id="ticket-details"
            side="right"
            class="w-full"
            on_cancel={JS.push("clear_ticket")}
          >
            <div :if={!@ticket} class="">
              <h3 class="text-foreground text-lg font-semibold">{gettext("Ticket Details")}</h3>

              <dl class="divide-accent border-accent mt-4 divide-y border-y">
                <div :for={_ <- 1..6}>
                  <.skeleton class="my-3 h-10 w-full" />
                </div>
              </dl>
            </div>

            <div :if={@ticket}>
              <h3 class="text-foreground text-lg font-semibold">{gettext("Ticket Details")}</h3>

              <dl class="divide-accent border-accent mt-4 divide-y border-y">
                <.list_item name={gettext("Order name")}>
                  {@ticket.order.user.full_name}
                </.list_item>
                <.list_item name={gettext("Order email")}>
                  {@ticket.order.user.email}
                </.list_item>
                <.list_item name={gettext("Signed up at")}>
                  {time_to_string(@ticket.order.updated_at, format: :short)}
                </.list_item>
                <.list_item name={gettext("Checked in at")}>
                  <span :if={is_nil(@ticket.checked_in_at)}>
                    {gettext("Not checked in")}
                  </span>
                  <span>
                    {time_to_string(@ticket.checked_in_at, format: :short)}
                  </span>
                </.list_item>

                <.list_item name={gettext("Ticket type")}>{@ticket.ticket_type.name}</.list_item>
                <div
                  :if={!@ticket.form_response}
                  class="flex flex-row items-center px-4 py-5 sm:gap-4 sm:px-6"
                >
                  <.icon name="hero-exclamation-triangle" class="text-destructive" />
                  <dt class="text-foreground text-sm">
                    {gettext("Attendeee has not filled in the required ticket information")}
                  </dt>
                </div>

                <%= if @ticket.form_response do %>
                  <.list_item
                    :for={qr <- @ticket.form_response.question_responses}
                    name={Localizer.localize(qr.question).name}
                  >
                    {qr}
                  </.list_item>
                <% end %>
              </dl>

              <.button
                type="submit"
                variant="outline"
                class="mt-4 w-full"
                phx-click={
                  JS.exec("phx-hide-sheet", to: "#ticket-details")
                  |> JS.push("clear_ticket")
                  |> JS.push("check_in", value: %{ticket_id: @ticket.id})
                }
              >
                {if @ticket.checked_in_at, do: gettext("Check out"), else: gettext("Check in")}
              </.button>
            </div>
          </.sheet_content>
        </.sheet>
      </.tabs>
    </div>
    """
  end

  def handle_info(%Tiki.Orders.Events.TicketCheckedIn{ticket: ticket}, socket) do
    {:noreply, stream_insert(socket, :tickets, ticket)}
  end

  attr :ticket, :map
  attr :id, :integer
  attr :rest, :global

  defp ticket_item(assigns) do
    ~H"""
    <li
      id={@id}
      class={[
        "relative flex cursor-pointer items-center justify-between gap-x-6 p-4 first:rounded-t-xl last:rounded-b-xl hover:bg-accent/50 sm:px-4 lg:px-6",
        @ticket.checked_in_at && "bg-success-background hover:bg-success-background/50"
      ]}
      phx-click={JS.push("check_in", value: %{ticket_id: @ticket.id})}
    >
      <div class="min-w-0">
        <div class="flex items-start gap-x-3">
          <.sheet_trigger
            :if={@ticket.name}
            target="ticket-details"
            class="text-foreground text-sm font-semibold leading-6 underline"
            click={JS.push("select_ticket", value: %{ticket_id: @ticket.id})}
          >
            {@ticket.name}
          </.sheet_trigger>
          <.badge variant="outline">
            <.icon name="hero-ticket-mini" class="text-muted-foreground mr-1 inline-block h-2 w-2" />
            <span class="text-muted-foreground text-xs font-normal">
              {Localizer.localize(@ticket.ticket_type).name}
            </span>
          </.badge>
        </div>
      </div>
      <div>
        <.input type="checkbox" name="ticket_id" value={@ticket.id} checked={@ticket.checked_in_at} />
      </div>
    </li>
    """
  end

  defp list_item(assigns) do
    ~H"""
    <div class="px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
      <dt class="text-muted-foreground text-sm font-medium">{@name}</dt>
      <dd class="text-foreground mt-1 text-sm sm:col-span-2 sm:mt-0">
        {render_slot(@inner_block)}
      </dd>
    </div>
    """
  end
end
