defmodule TikiWeb.PurchaseLive.TicketsComponent do
  use TikiWeb, :live_component

  alias Tiki.Tickets
  alias Tiki.Orders
  alias Tiki.Releases
  alias Tiki.Localizer

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-4">
      <h2 class="text-xl/6 font-semibold">{gettext("Tickets")}</h2>
      <div :if={@error != nil} class="mt-3 text-red-700">
        {@error}
      </div>

      <div class="flex flex-col gap-3">
        <div :if={@ticket_types == []} class="text-center text-lg">
          <h3 class="text-foreground text-sm font-semibold">
            {gettext("No tickets available")}
          </h3>
          <p class="text-muted-foreground mt-1 text-sm">
            {gettext("Please contact the event organizer if you have any questions.")}
          </p>
        </div>

        <div :for={{date, ticket_types} <- @ticket_types} class="flex flex-col gap-3">
          <div :if={date}>
            <span class="font-semibold">
              {time_to_string(date, format: :MMMEd)}
            </span>
            ·
            <span class="text-muted-foreground">
              {time_to_string(date, format: :Hm)}
            </span>
          </div>
          <div :for={ticket_type <- ticket_types} class="bg-accent overflow-hidden rounded-xl">
            <div :if={ticket_type.promo_code != nil}>
              <div class="bg-cyan-700 py-1 text-center text-sm text-cyan-100">
                {ticket_type.promo_code}
              </div>
            </div>

            <div class="flex flex-row justify-between px-4 py-4">
              <div class="flex flex-col">
                <h3 class="text-md pb-1 font-semibold">{Localizer.localize(ticket_type).name}</h3>
                <div class="text-muted-foreground text-sm">{ticket_type.price} kr</div>
              </div>

              <div :if={purchasable(ticket_type)} class="flex flex-row items-center gap-2">
                <button
                  :if={@counts[ticket_type.id] > 0}
                  class="bg-background flex h-8 w-8 items-center justify-center rounded-full text-2xl shadow-md hover:bg-accent hover:cursor-pointer"
                  phx-click={JS.push("dec", value: %{id: ticket_type.id})}
                  phx-target={@myself}
                >
                  <.icon name="hero-minus-mini" />
                </button>

                <div class="flex h-10 w-8 items-center justify-center rounded-lg bg-slate-200 dark:bg-zinc-900">
                  {@counts[ticket_type.id]}
                </div>

                <button
                  :if={compare_available(@counts, ticket_type, @event) in [:gt, :eq]}
                  class="bg-accent flex h-8 w-8 items-center justify-center rounded-full text-2xl shadow-md"
                  disabled
                >
                  <.icon name="hero-plus-mini" />
                </button>

                <button
                  :if={compare_available(@counts, ticket_type, @event) == :lt}
                  class="bg-background flex h-8 w-8 items-center justify-center rounded-full text-2xl shadow-md hover:bg-accent hover:cursor-pointer"
                  phx-click={JS.push("inc", value: %{id: ticket_type.id})}
                  phx-target={@myself}
                >
                  <.icon name="hero-plus-mini" />
                </button>
              </div>
            </div>

            <.not_available_label ticket_type={ticket_type} />
          </div>
        </div>
      </div>

      <div class="flex flex-row justify-between pb-6 lg:pb-0">
        <.form
          for={%{}}
          as={:promo_form}
          phx-change="update_promo"
          phx-submit="activate_promo"
          class="flex w-full flex-row justify-between"
          phx-target={@myself}
        >
          <input
            type="text"
            name="code"
            placeholder={gettext("Promo code")}
            value={@promo_code}
            class="border-input bg-background ring-offset-background flex h-10 w-full rounded-md border px-3 py-2 text-sm placeholder:text-muted-foreground focus:ring-offset-background focus:border-input focus:ring-ring focus:outline-hidden focus:ring-2 focus:ring-offset-2 md:w-auto"
          />
          <.button :if={@promo_code != ""}>{gettext("Activate")}</.button>
        </.form>

        <div class="bg-background border-border fixed right-0 bottom-0 left-0 z-30 border-t px-6 py-3 lg:relative lg:border-none lg:p-0">
          <%= if Enum.map(@counts, &elem(&1, 1)) |> Enum.sum() == 0 do %>
            <.link href="#tickets" class={["w-full", @promo_code != "" && "hidden"]}>
              <.button class="w-full">{gettext("Tickets")}</.button>
            </.link>
          <% else %>
            <.button
              phx-click="request-tickets"
              phx-target={@myself}
              class={"#{@promo_code != "" && "lg:hidden"} w-full"}
            >
              {gettext("Buy")}
            </.button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :ticket_type, :any, required: true

  defp not_available_label(%{ticket_type: tt} = assigns) do
    now = DateTime.utc_now()

    assigns =
      cond do
        !tt.purchasable ->
          assign(assigns, label: gettext("Ticket not available"))

        tt.expire_time && DateTime.compare(now, tt.expire_time) == :gt ->
          assign(assigns, label: gettext("Ticket not available"))

        tt.release_time && DateTime.compare(now, tt.release_time) == :lt ->
          assign(assigns,
            label:
              "#{gettext("Ticket releases at")} #{time_to_string(tt.release_time, format: :short)}"
          )

        tt.available == 0 ->
          assign(assigns, label: gettext("Sold out"))

        active_release?(tt) ->
          assign(assigns, label: gettext("Ticket is part of an active release."))

        true ->
          assign(assigns, label: nil)
      end

    ~H"""
    <div
      :if={@label}
      class="text-muted-foreground bg-muted-foreground/5 py-1 text-center text-sm dark:bg-background/50"
    >
      {@label}
    </div>
    """
  end

  @impl Phoenix.LiveComponent
  def update(%{action: {:tickets_updated, ticket_types}}, socket) do
    # TODO: make sure that this is automatically updated when a ticket type is released, eg. via Oban

    {:ok, assign_ticket_types(socket, ticket_types)}
  end

  def update(%{event: event} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       promo_code: "",
       promo_codes: Map.get(assigns, :promo_codes, []),
       error: nil
     )
     |> assign_ticket_types(get_available_ticket_types(event.id))}
  end

  defp assign_ticket_types(socket, ticket_types) do
    counts =
      for tt <- ticket_types, into: %{} do
        value = get_in(socket.assigns, [:counts, tt.id]) || 0
        {tt.id, min(value, tt.available) |> max(0)}
      end

    ticket_types =
      ticket_types
      |> Enum.filter(fn tt ->
        tt.promo_code == nil || tt.promo_code in socket.assigns.promo_codes
      end)
      |> Enum.sort_by(fn tt -> tt.price end)

    ticket_types =
      case socket.assigns[:release] do
        nil ->
          ticket_types

        %Releases.Release{} = release ->
          Enum.filter(ticket_types, fn tt -> tt.release && tt.release.id == release.id end)
          |> Enum.map(fn tt -> %{tt | release: nil} end)
      end
      |> Enum.group_by(fn tt -> tt.start_time end)
      |> Enum.sort(fn {start_a, _}, {start_b, _} ->
        case {start_a, start_b} do
          {nil, _} -> false
          {_, nil} -> true
          {a, b} -> DateTime.compare(a, b) in [:lt, :eq]
        end
      end)

    assign(socket, ticket_types: ticket_types, counts: counts)
  end

  @impl Phoenix.LiveComponent
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

    {:noreply,
     assign(socket, promo_code: "", promo_codes: [code | codes])
     |> assign_ticket_types(get_available_ticket_types(event_id))}
  end

  def handle_event("request-tickets", _params, socket) do
    to_purchase =
      Enum.filter(socket.assigns.counts, fn {_, count} -> count > 0 end)
      |> Enum.into(%{})

    %{event: %{id: event_id}} = socket.assigns

    with {:ok, order} <- Orders.reserve_tickets(event_id, to_purchase) do
      to =
        case socket.assigns[:embedded] do
          nil ->
            ~p"/events/#{event_id}/purchase/#{order}?#{%{"promo_codes" => socket.assigns.promo_codes}}"

          true ->
            ~p"/embed/events/#{event_id}/purchase/#{order}"
        end

      {:noreply, push_navigate(socket, to: to)}
    else
      {:error, reason} ->
        {:noreply, assign(socket, error: reason)}
    end
  end

  defp purchasable(ticket_type) do
    now = DateTime.utc_now()

    cond do
      !ticket_type.purchasable -> false
      ticket_type.expire_time && DateTime.compare(now, ticket_type.expire_time) == :gt -> false
      ticket_type.release_time && DateTime.compare(now, ticket_type.release_time) == :lt -> false
      active_release?(ticket_type) -> false
      true -> true
    end
  end

  defp compare_available(counts, ticket_type, event) do
    total = Enum.reduce(counts, 0, fn {_, count}, acc -> acc + count end)

    cond do
      total >= event.max_order_size ->
        :gt

      counts[ticket_type.id] > ticket_type.available &&
          counts[ticket_type.id] > ticket_type.purchase_limit ->
        :gt

      counts[ticket_type.id] < ticket_type.available &&
          counts[ticket_type.id] < ticket_type.purchase_limit ->
        :lt

      true ->
        :eq
    end
  end

  defp get_available_ticket_types(event_id) do
    Tickets.get_cached_available_ticket_types(event_id)
  end

  defp active_release?(ticket_type) do
    case ticket_type.release do
      nil -> false
      %Releases.Release{} = release -> Releases.is_active?(release)
    end
  end
end
