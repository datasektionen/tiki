defmodule TikiWeb.AdminLive.Attendees.Show do
  use TikiWeb, :live_view

  alias Tiki.Events
  alias Tiki.Orders

  import TikiWeb.Component.Card

  def mount(%{"id" => event_id, "ticket_id" => ticket_id}, _session, socket) do
    event = Events.get_event!(event_id)
    ticket = Orders.get_ticket!(ticket_id)

    {:ok, assign(socket, event: event, ticket: ticket)}
  end

  def handle_params(_params, _uri, socket) do
    %{event: event, ticket: ticket} = socket.assigns

    {:noreply,
     assign_breadcrumbs(socket, [
       {"Dashboard", ~p"/admin/"},
       {"Events", ~p"/admin/events"},
       {event.name, ~p"/admin/events/#{event.id}"},
       {"Attendees", ~p"/admin/events/#{event.id}/attendees"},
       {ticket.order.user.full_name, ~p"/admin/events/#{event.id}/attendees/#{ticket.id}"}
     ])}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-4">
      <%!-- Ticket information --%>
      <.information_card name="Ticket" description="Information about ticket.">
        <:item name="Signed up at" value={Calendar.strftime(@ticket.order.updated_at, "%x %H:%M")} />
        <:item name="Ticket type" value={@ticket.ticket_type.name} />
      </.information_card>

      <%!-- Order information --%>
      <.information_card name="Order" description="Information about order.">
        <:item name="Order number" value={@ticket.order.id} />
        <:item name="Email" value={@ticket.order.user.email} />
      </.information_card>
    </div>
    """
  end

  attr :name, :string
  attr :description, :string

  slot :item, required: true do
    attr :name, :string, required: true
    attr :value, :string, required: true
  end

  defp information_card(assigns) do
    ~H"""
    <.card>
      <.card_header>
        <.card_title><%= @name %></.card_title>
        <.card_description><%= @description %></.card_description>
      </.card_header>

      <div class="divide-accent border-accent divide-y border-t">
        <dl class="divide-accent divide-y">
          <div :for={item <- @item} class="px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
            <dt class="text-muted-foreground text-sm font-medium"><%= item.name %></dt>
            <dd class="text-foreground mt-1 text-sm sm:col-span-2 sm:mt-0"><%= item.value %></dd>
          </div>
        </dl>
      </div>
    </.card>
    """
  end
end
