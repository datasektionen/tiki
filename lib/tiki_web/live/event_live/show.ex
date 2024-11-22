defmodule TikiWeb.EventLive.Show do
  use TikiWeb, :live_view

  alias TikiWeb.EventLive.PurchaseComponent
  alias Tiki.Events
  alias Tiki.Presence

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="mb-2 flex flex-col gap-2">
      <div :if={@event.image_url != nil} class="pb-4">
        <img class="aspect-video w-full rounded-xl object-cover" src={@event.image_url} />
      </div>

      <div class="flex flex-row items-center justify-between">
        <div>
          <div class="text-muted-foreground">
            <%= Calendar.strftime(@event.event_date, "%d %B", month_names: &month_name/1) %>
          </div>
          <h1 class="text-3xl font-bold"><%= @event.name %></h1>
        </div>

        <.link patch={~p"/events/#{@event}/purchase"}>
          <.button>Köp biljetter</.button>
        </.link>
      </div>

      <div class="text-muted-foreground my-4 flex flex-col gap-1">
        <div class="inline-flex items-center gap-2">
          <.icon name="hero-calendar" />
          <%= Calendar.strftime(@event.event_date, "%Y-%m-%d vid %H:%M") %>
        </div>
        <div class="inline-flex items-center gap-2">
          <.icon name="hero-map-pin" />
          <%= @event.location %>
        </div>
      </div>
      <p class="-mt-8 whitespace-pre-wrap">
        <%= @event.description %>
      </p>
    </div>

    <div :if={@live_action == :purchase}>
      <.live_component
        module={TikiWeb.EventLive.PurchaseComponent}
        id={@event.id}
        title={@page_title}
        action={@live_action}
        event={@event}
        patch={~p"/events/#{@event}"}
        current_user={@current_user}
      />
    </div>

    <div class="bg-background fixed right-4 bottom-4 rounded-full border px-4 py-2 shadow-sm">
      <%= max(@online_count, 0) %> online
    </div>
    """
  end

  @impl true
  def mount(%{"id" => event_id}, _session, socket) do
    ticket_types = Events.get_ticket_types(event_id)
    event = Events.get_event!(event_id)

    initial_count = Presence.list("presence:event:#{event_id}") |> map_size

    if connected?(socket) do
      TikiWeb.Endpoint.subscribe("presence:event:#{event_id}")
      Presence.track(self(), "presence:event:#{event_id}", socket.id, %{})
    end

    {:ok, assign(socket, ticket_types: ticket_types, event: event, online_count: initial_count)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  def apply_action(socket, :purchase, _params) do
    socket
    |> assign(:page_title, "Köp biljett")
  end

  def apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, socket.assigns.event.name)
  end

  @impl true
  def handle_info(
        %{event: "presence_diff", payload: %{joins: joins, leaves: leaves}},
        %{assigns: %{online_count: count}} = socket
      ) do
    online_count = count + map_size(joins) - map_size(leaves)
    {:noreply, assign(socket, :online_count, online_count)}
  end

  @impl true
  def handle_info({:timeout, %{id: id} = meta}, socket) do
    send_update(PurchaseComponent, id: id, action: {:timeout, meta})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:tickets_updated, _ticket_types} = msg, socket) do
    send_update(PurchaseComponent, id: socket.assigns.event.id, action: msg)
    {:noreply, socket}
  end

  defp month_name(month) do
    {"januari", "februari", "mars", "april", "maj", "juni", "juli", "augusti", "september",
     "oktober", "november", "december"}
    |> elem(month - 1)
  end
end
