defmodule TikiWeb.EventLive.Show do
  use TikiWeb, :live_view

  alias Tiki.Events
  alias Tiki.Presence
  alias Tiki.Orders
  alias TikiWeb.PurchaseLive.TicketsComponent
  alias Tiki.Localizer
  alias Tiki.Releases

  import TikiWeb.Component.Card
  import TikiWeb.Component.Avatar

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div :if={@live_action not in [:embedded, :embedded_purchase]} class="flex flex-col gap-4">
      <h1 class="text-2xl font-bold leading-9">{@event.name}</h1>
      <div class="flex flex-col items-start gap-4 lg:grid lg:grid-cols-3">
        <div class="col-span-2 flex flex-col gap-4">
          <div :if={@event.image_url != nil} class="">
            <img
              class="aspect-video w-full rounded-xl object-cover"
              src={image_url(@event.image_url)}
            />
          </div>

          <div class="text-muted-foreground flex flex-col gap-1">
            <div class="inline-flex items-center gap-2">
              <.icon name="hero-calendar" />
              {event_time(@event)}
            </div>
            <div class="inline-flex items-center gap-2">
              <.icon name="hero-map-pin" />
              {@event.location}
            </div>
          </div>
          <p class="whitespace-pre-wrap">{@event.description}</p>

          <div class="flex flex-col gap-4">
            <.card_title>{gettext("Organized by")}</.card_title>
            <div class="flex flex-row items-center gap-2">
              <.avatar>
                <.avatar_image src={image_url(@event.team.logo_url, width: 64, height: 64)} />
                <.avatar_fallback>
                  {@event.team.name}
                </.avatar_fallback>
              </.avatar>

              <.link href={"mailto:#{@event.team.contact_email}"} class="hover:underline">
                {@event.team.name}
              </.link>
            </div>
          </div>
        </div>

        <div class="flex w-full flex-col gap-6 lg:sticky lg:top-4" id="tickets">
          <div :if={@releases != []}>
            <div class="flex flex-col gap-4">
              <h2 class="text-xl/6 font-semibold">{gettext("Ticket releases")}</h2>

              <div class="flex flex-col gap-3">
                <div
                  :for={release <- @releases}
                  class="bg-accent flex flex-col overflow-hidden rounded-xl"
                >
                  <div class="flex flex-row justify-between px-4 py-4">
                    <div class="flex flex-col">
                      <h3 class="text-md pb-1 font-semibold">{Localizer.localize(release).name}</h3>
                      <div class="text-sm">
                        <span class="font-semibold">
                          {time_to_string(release.starts_at, format: :MMMEd)}
                        </span>
                        ·
                        <span class="text-muted-foreground">
                          {time_to_string(release.starts_at, format: :Hm)}
                        </span>
                      </div>
                    </div>
                  </div>

                  <.link
                    navigate={~p"/events/#{@event}/releases/#{release}"}
                    class="text-background bg-foreground py-2 text-center text-sm hover:bg-muted-foreground hover:cursor-pointer"
                  >
                    {gettext("Join release")}
                  </.link>
                </div>
              </div>
            </div>
          </div>
          <.live_component
            module={TicketsComponent}
            id="tickets-component"
            current_user={@current_user}
            event={@event}
            order={@order}
            promo_codes={@promo_codes}
          />
        </div>
      </div>
    </div>

    <.live_component
      :if={@live_action == :embedded}
      embedded
      module={TicketsComponent}
      id="tickets-component"
      current_user={@current_user}
      event={@event}
      order={@order}
    />

    <.live_component
      :if={@live_action in [:purchase, :embedded_purchase]}
      module={TikiWeb.PurchaseLive.PurchaseComponent}
      current_user={@current_user}
      action={@live_action}
      id={@event.id}
      event={@event}
      order={@order}
      patch={~p"/events/#{@event}"}
    />

    <%!-- <div class="bg-background shadow-xs fixed right-4 bottom-4 rounded-full border px-4 py-2">
      {max(@online_count, 0)} online
    </div> --%>
    """
  end

  @impl true
  def mount(%{"event_id" => event_id}, _session, socket) do
    event =
      Events.get_event!(event_id, preload_ticket_types: true)
      |> Tiki.Localizer.localize()

    releases =
      Enum.map(event.ticket_batches, & &1.release)
      |> Enum.filter(& &1)

    initial_count = Presence.list("presence:event:#{event_id}") |> map_size

    if connected?(socket) do
      TikiWeb.Endpoint.subscribe("presence:event:#{event_id}")
      Orders.subscribe(event.id)
      Releases.subscribe_to_event(event.id)
      Presence.track(self(), "presence:event:#{event_id}", socket.id, %{})
    end

    layout =
      case socket.assigns.live_action do
        :embedded_purchase -> :blank
        :embedded -> :embedded
        _ -> :app
      end

    {:ok,
     assign(socket,
       event: event,
       online_count: initial_count,
       order: nil
     )
     |> assign_releases(releases), layout: {TikiWeb.Layouts, layout}}
  end

  @impl true
  def handle_params(params, _url, socket) do
    promo_codes =
      case Map.get(params, "promo_codes", []) do
        codes when is_list(codes) -> codes
        _ -> []
      end

    {:noreply,
     apply_action(socket, socket.assigns.live_action, params)
     |> assign(promo_codes: promo_codes)}
  end

  def apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, socket.assigns.event.name)
  end

  def apply_action(socket, :embedded, _params) do
    socket
    |> assign(:page_title, socket.assigns.event.name)
  end

  def apply_action(socket, purchase_action, %{"order_id" => order_id})
      when purchase_action in [:purchase, :embedded_purchase] do
    order = Orders.get_order!(order_id)

    if connected?(socket) do
      Orders.subscribe_to_order(order_id)
    end

    case order.status do
      :paid ->
        url =
          if socket.assigns.live_action in [:embedded, :embedded_purchase],
            do: ~p"/embed/orders/#{order.id}",
            else: ~p"/orders/#{order.id}"

        push_navigate(socket, to: url)

      _ ->
        assign(socket, order: order)
    end
  end

  @impl true
  def handle_info({:releases_updated, releases}, socket) do
    {:noreply, assign_releases(socket, releases)}
  end

  @impl true
  def handle_info({:tickets_updated, _} = msg, socket) do
    send_update(TicketsComponent, id: "tickets-component", action: msg)
    {:noreply, socket}
  end

  def handle_info({:cancelled, order}, socket) do
    {:noreply, assign(socket, order: order)}
  end

  def handle_info({:paid, order}, socket) do
    if order.status == :paid do
      url =
        if socket.assigns.live_action in [:embedded, :embedded_purchase],
          do: ~p"/embed/orders/#{order.id}",
          else: ~p"/orders/#{order.id}"

      {:noreply,
       put_flash(socket, :info, gettext("Order paid!"))
       |> push_navigate(to: url)}
    else
      {:noreply, assign(socket, order: order)}
    end
  end

  def handle_info(
        %{event: "presence_diff", payload: %{joins: joins, leaves: leaves}},
        %{assigns: %{online_count: count}} = socket
      ) do
    online_count = count + map_size(joins) - map_size(leaves)
    {:noreply, assign(socket, :online_count, online_count)}
  end

  defp event_time(event) do
    case event do
      %Tiki.Events.Event{start_time: start_time, end_time: nil} ->
        time_to_string(start_time)

      %Tiki.Events.Event{start_time: start_time, end_time: end_time} ->
        Tiki.Cldr.Date.Interval.to_string!(start_time, end_time, format: :long)
        |> String.capitalize()
    end
  end

  defp assign_releases(socket, releases) do
    releases =
      releases
      |> Enum.sort_by(& &1.starts_at)
      |> Enum.filter(&Releases.is_active?/1)

    assign(socket, releases: releases)
  end
end
