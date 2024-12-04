defmodule TikiWeb.PurchaseLive.Tickets do
  use TikiWeb, :live_view

  alias Phoenix.LiveView.AsyncResult
  import TikiWeb.Component.Skeleton

  alias Tiki.Events
  alias Tiki.Tickets
  alias Tiki.Orders
  alias Tiki.Presence

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @event.name %>
        <:subtitle>
          <div>Köp biljetter till eventet här.</div>
        </:subtitle>
      </.header>

      <div :if={@error != nil} class="mt-3 text-red-700">
        <%= @error %>
      </div>

      <div class="flex flex-col gap-3 pt-4">
        <.async_result :let={ticket_types} assign={@ticket_types}>
          <:loading>
            <.skeleton class="h-20 w-full" />
            <.skeleton class="h-20 w-full" />
            <.skeleton class="h-20 w-full" />
          </:loading>
          <:failed :let={_failure}>there was an erorr loading ticket types</:failed>
          <div :for={ticket_type <- ticket_types} class="bg-accent overflow-hidden rounded-xl">
            <div :if={ticket_type.promo_code != nil}>
              <div class="bg-cyan-700 py-1 text-center text-sm text-cyan-100">
                <%= ticket_type.promo_code %>
              </div>
            </div>

            <div class="flex flex-row justify-between px-4 py-4">
              <div class="flex flex-col">
                <h3 class="pb-1 text-xl font-bold"><%= ticket_type.name %></h3>
                <div class="text-muted-foreground"><%= ticket_type.price %> kr</div>
              </div>

              <div class="flex flex-row items-center gap-2">
                <button
                  :if={@counts[ticket_type.id] > 0}
                  class="bg-background flex h-8 w-8 items-center justify-center rounded-full text-2xl shadow-md hover:bg-accent hover:cursor-pointer"
                  phx-click={JS.push("dec", value: %{id: ticket_type.id})}
                >
                  <.icon name="hero-minus-mini" />
                </button>

                <div class="flex h-10 w-8 items-center justify-center rounded-lg bg-slate-200 dark:bg-zinc-900">
                  <%= @counts[ticket_type.id] %>
                </div>

                <button
                  :if={@counts[ticket_type.id] >= ticket_type.available}
                  class="bg-accent flex h-8 w-8 items-center justify-center rounded-full text-2xl shadow-md"
                  disabled
                >
                  <.icon name="hero-plus-mini" />
                </button>

                <button
                  :if={@counts[ticket_type.id] < ticket_type.available}
                  class="bg-background flex h-8 w-8 items-center justify-center rounded-full text-2xl shadow-md hover:bg-accent hover:cursor-pointer"
                  phx-click={JS.push("inc", value: %{id: ticket_type.id})}
                >
                  <.icon name="hero-plus-mini" />
                </button>
              </div>
            </div>

            <div
              :if={ticket_type.available <= 0}
              class="text-muted-foreground bg-accent py-1 text-center text-sm"
            >
              Biljetterna är slutsålda
            </div>
          </div>
        </.async_result>
      </div>

      <div class="flex flex-row justify-between pt-4">
        <.form
          for={%{}}
          as={:promo_form}
          phx-change="update_promo"
          phx-submit="activate_promo"
          class="flex w-full flex-row justify-between"
        >
          <input
            type="text"
            name="code"
            placeholder={gettext("Promo code")}
            value={@promo_code}
            class="border-input bg-background ring-offset-background flex h-10 rounded-md border px-3 py-2 text-sm placeholder:text-muted-foreground focus:ring-offset-background focus:border-input focus:ring-ring focus:outline-hidden focus:ring-2 focus:ring-offset-2"
          />
          <.button :if={@promo_code != ""}>Aktivera</.button>
        </.form>
        <.button :if={@promo_code == ""} phx-click="request-tickets">
          <span>Fortsätt</span>
        </.button>
      </div>
      <.live_component
        :if={@live_action == :purchase}
        module={TikiWeb.PurchaseLive.PurchaseComponent}
        id={@event.id}
        event={@event}
        order={@order}
        patch={~p"/events/#{@event}"}
      />
    </div>
    """
  end

  @impl Phoenix.LiveView
  def mount(%{"event_id" => event_id}, _session, socket) do
    event = Events.get_event!(event_id)

    if connected?(socket) do
      Orders.subscribe(event.id)
      Presence.track(self(), "presence:event:#{event_id}", socket.id, %{})
    end

    {:ok,
     assign(socket,
       event: event,
       promo_code: "",
       promo_codes: [],
       error: nil,
       ticket_types: AsyncResult.loading()
     )
     |> start_async(:ticket_types, fn -> get_available_ticket_types(event.id) end)}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :tickets, _params), do: socket

  defp apply_action(socket, :purchase, %{"order_id" => order_id}) do
    order = Orders.get_order!(order_id)

    if connected?(socket) do
      Orders.subscribe_to_order(order_id)
    end

    case order.status do
      :paid ->
        push_navigate(socket, to: ~p"/orders/#{order.id}")

      _ ->
        assign(socket, order: order)
    end
  end

  defp get_available_ticket_types(event_id) do
    Tickets.get_available_ticket_types(event_id)
  end

  @impl Phoenix.LiveView
  def handle_async(:ticket_types, {:ok, ticket_types}, socket) do
    {:noreply, assign_ticket_types(socket, ticket_types)}
  end

  defp assign_ticket_types(socket, ticket_types) do
    %{ticket_types: tts} = socket.assigns

    counts =
      for tt <- ticket_types, into: %{} do
        value = get_in(socket.assigns, [:counts, tt.id]) || 0
        {tt.id, min(value, tt.available)}
      end

    ticket_types =
      ticket_types
      |> Enum.filter(fn tt ->
        tt.promo_code == nil || tt.promo_code in socket.assigns.promo_codes
      end)
      |> Enum.filter(fn tt -> tt.purchasable end)
      |> Enum.sort(fn tt_a, tt_b ->
        dawn_of_time = DateTime.from_unix!(0)

        case DateTime.compare(tt_a.start_time || dawn_of_time, tt_b.start_time || dawn_of_time) do
          :gt -> true
          :lt -> false
          :eq -> tt_a.price < tt_b.price
        end
      end)

    assign(socket, ticket_types: AsyncResult.ok(tts, ticket_types), counts: counts)
  end

  @impl Phoenix.LiveView
  def handle_event("inc", %{"id" => id}, socket) do
    counts = Map.update(socket.assigns.counts, id, 0, &(&1 + 1))
    {:noreply, assign(socket, counts: counts)}
  end

  def handle_event("dec", %{"id" => id}, socket) do
    counts = Map.update(socket.assigns.counts, id, 0, &(&1 - 1))
    {:noreply, assign(socket, counts: counts)}
  end

  def handle_event("update_promo", %{"code" => code}, socket) do
    {:noreply, assign(socket, promo_code: code)}
  end

  def handle_event("activate_promo", %{"code" => code}, socket) do
    %{event: %{id: event_id}, promo_codes: codes} = socket.assigns
    codes = [code | codes]

    {:noreply,
     assign(socket, promo_code: "", promo_codes: codes)
     |> start_async(:ticket_types, fn -> get_available_ticket_types(event_id) end)}
  end

  def handle_event("request-tickets", _params, socket) do
    to_purchase =
      Enum.filter(socket.assigns.counts, fn {_, count} -> count > 0 end)
      |> Enum.into(%{})

    user_id =
      case socket.assigns.current_user do
        nil -> nil
        user -> user.id
      end

    %{event: %{id: event_id}} = socket.assigns

    with {:ok, order} <- Orders.reserve_tickets(event_id, to_purchase, user_id) do
      {:noreply, push_patch(socket, to: ~p"/events/#{event_id}/purchase/#{order}")}
    else
      {:error, reason} ->
        {:noreply, assign(socket, error: reason)}
    end
  end

  @impl true
  def handle_info({:tickets_updated, ticket_types}, socket) do
    {:noreply, assign_ticket_types(socket, ticket_types)}
  end

  def handle_info({:cancelled, order}, socket) do
    {:noreply, assign(socket, order: order)}
  end

  def handle_info({:paid, order}, socket) do
    if order.status == :paid do
      {:noreply,
       put_flash(socket, :info, gettext("Order paid!"))
       |> push_navigate(to: ~p"/orders/#{order.id}")}
    else
      {:noreply, assign(socket, order: order)}
    end
  end

  @impl Phoenix.LiveView
  def handle_info(
        %{event: "presence_diff", payload: %{joins: joins, leaves: leaves}},
        %{assigns: %{online_count: count}} = socket
      ) do
    online_count = count + map_size(joins) - map_size(leaves)
    {:noreply, assign(socket, :online_count, online_count)}
  end
end
