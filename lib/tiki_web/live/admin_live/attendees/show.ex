defmodule TikiWeb.AdminLive.Attendees.Show do
  use TikiWeb, :live_view

  alias Tiki.Events
  alias Tiki.Orders

  def mount(%{"id" => event_id, "ticket_id" => ticket_id}, _session, socket) do
    event = Events.get_event!(event_id)
    ticket = Orders.get_ticket!(ticket_id)

    {:ok, assign(socket, event: event, ticket: ticket)}
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
    <div class="overflow-hidden bg-white shadow sm:rounded-lg">
      <div class="px-4 py-5 sm:px-6">
        <h3 class="text-base font-semibold leading-6 text-gray-900"><%= @name %></h3>
        <p class="mt-1 max-w-2xl text-sm text-gray-500"><%= @description %></p>
      </div>
      <div class="divide-y divide-gray-200 border-t border-gray-200">
        <dl class="divide-y divide-gray-200">
          <div :for={item <- @item} class="px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
            <dt class="text-sm font-medium text-gray-500"><%= item.name %></dt>
            <dd class="mt-1 text-sm text-gray-900 sm:col-span-2 sm:mt-0"><%= item.value %></dd>
          </div>
        </dl>
      </div>
    </div>
    """
  end
end
