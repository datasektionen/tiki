defmodule TikiWeb.AdminLive.Releases.Show do
  alias Tiki.Releases
  use TikiWeb, :live_view

  alias Tiki.Events
  alias Tiki.Localizer

  import TikiWeb.Component.Badge
  import TikiWeb.Component.Card

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="grid gap-4">
      <.card_title class="sm:col-span-6">
        {gettext("Release: %{release_name}", release_name: Localizer.localize(@release).name)}
      </.card_title>

      <%!-- Stat cards --%>
      <div class="grid grid-cols-2 gap-3 sm:col-span-6 sm:grid-cols-4">
        <.stat_card label={gettext("Phase")}>
          <.phase_badge phase={@phase} />
        </.stat_card>

        <.stat_card label={gettext("Signups")}>
          <span class="text-2xl font-semibold">{@signup_count}</span>
        </.stat_card>

        <.stat_card label={gettext("Tickets requested")}>
          <span class="text-2xl font-semibold">{@total_items}</span>
        </.stat_card>

        <.stat_card :if={@drawn?} label={gettext("Converted")}>
          <span class="text-2xl font-semibold">{@paid_count}/{@winner_count}</span>
        </.stat_card>

        <.stat_card label={gettext("Opens")}>
          <span class="text-sm font-medium">{time_to_string(@release.opens_at, format: :short)}</span>
        </.stat_card>

        <.stat_card label={gettext("Draw")}>
          <span class="text-sm font-medium">{time_to_string(@lottery_end, format: :short)}</span>
        </.stat_card>

        <.stat_card label={gettext("Pay deadline")}>
          <span class="text-sm font-medium">{time_to_string(@purchase_end, format: :short)}</span>
        </.stat_card>
      </div>

      <%!-- Signup list --%>
      <.card class="sm:col-span-6">
        <ul
          id="sign_ups"
          phx-update="stream"
          role="list"
          class="divide-accent divide-y"
        >
          <.sign_up_item
            :for={{id, sign_up} <- @streams.sign_ups}
            sign_up={sign_up}
            id={id}
            pre_draw={@pre_draw}
          />
        </ul>
      </.card>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :rest, :global
  attr :icon, :string, default: nil
  slot :inner_block, required: true

  defp stat_card(assigns) do
    ~H"""
    <.card>
      <.card_header class="flex flex-row items-center justify-between space-y-0 pt-4 pb-2">
        <.card_title class="text-muted-foreground text-xs font-normal">
          {@label}
        </.card_title>
        <.icon :if={@icon} name={@icon} class="text-muted-foreground h-4 w-4" />
      </.card_header>
      <.card_content class="pb-4">
        {render_slot(@inner_block)}
      </.card_content>
    </.card>
    """
  end

  attr :phase, :atom, required: true

  defp phase_badge(assigns) do
    ~H"""
    <.badge variant={phase_variant(@phase)}>
      {phase_label(@phase)}
    </.badge>
    """
  end

  defp phase_variant(:open), do: "success"
  defp phase_variant(:purchase), do: "warning"
  defp phase_variant(:drawing), do: "warning"
  defp phase_variant(_), do: "secondary"

  defp phase_label(:scheduled), do: gettext("Scheduled")
  defp phase_label(:open), do: gettext("Open")
  defp phase_label(:drawing), do: gettext("Drawing")
  defp phase_label(:purchase), do: gettext("Purchase")
  defp phase_label(:released), do: gettext("Released")

  attr :id, :any
  attr :sign_up, :map
  attr :pre_draw, :boolean
  attr :rest, :global

  defp sign_up_item(assigns) do
    ~H"""
    <li
      id={@id}
      class={[
        "relative flex items-center justify-between gap-x-6 px-2 py-3 first:rounded-t-xl last:rounded-b-xl hover:bg-accent/50 sm:px-2 lg:px-4",
        @sign_up.status == :seeded && "bg-success-background",
        @sign_up.status == :rejected && "bg-error-background",
        @sign_up.status in [:drawn, :lost] && "opacity-75"
      ]}
    >
      <div class="flex min-w-0 flex-1 items-center gap-x-3">
        <span class="text-muted-foreground shrink-0 text-xs">
          {time_to_string(@sign_up.inserted_at, format: :Hms)}
        </span>
        <span class="truncate font-medium">{@sign_up.user.full_name}</span>
        <.badge :if={@sign_up.user.year_tag} variant="outline">
          <span class="text-xs">{@sign_up.user.year_tag}</span>
        </.badge>
        <.signup_status_badge status={@sign_up.status} order={@sign_up.order} />
      </div>

      <div class="text-muted-foreground ml-4 shrink-0 text-right text-xs">
        {signup_items_summary(@sign_up.items)}
      </div>

      <div class="ml-4 flex shrink-0 items-center gap-2">
        <.button
          variant={if @sign_up.status == :seeded, do: "secondary", else: "ghost"}
          size="sm"
          phx-click={@pre_draw && "seed"}
          phx-value-id={@sign_up.id}
          disabled={not @pre_draw or @sign_up.status not in [:queued, :rejected, :seeded]}
        >
          {gettext("Seed")}
        </.button>
        <.button
          variant={if @sign_up.status == :rejected, do: "secondary", else: "ghost"}
          size="sm"
          phx-click={@pre_draw && "reject"}
          phx-value-id={@sign_up.id}
          disabled={not @pre_draw or @sign_up.status not in [:queued, :seeded, :rejected]}
        >
          {gettext("Reject")}
        </.button>
      </div>
    </li>
    """
  end

  attr :status, :atom, required: true
  attr :order, :any, default: nil

  defp signup_status_badge(assigns) do
    ~H"""
    <.badge :if={@status == :seeded} variant="success">{gettext("Seeded")}</.badge>
    <.badge :if={@status == :rejected} variant="destructive">{gettext("Rejected")}</.badge>
    <.badge :if={@status == :drawn} variant={order_badge_variant(@order)}>
      {order_badge_label(@order)}
    </.badge>
    <.badge :if={@status == :lost} variant="secondary">{gettext("Lost")}</.badge>
    """
  end

  defp order_badge_variant(%{status: :paid}), do: "success"
  defp order_badge_variant(%{status: :cancelled}), do: "destructive"
  defp order_badge_variant(_), do: "warning"

  defp order_badge_label(%{status: :paid}), do: gettext("Paid")
  defp order_badge_label(%{status: :cancelled}), do: gettext("Forfeited")
  defp order_badge_label(_), do: gettext("Won — unpaid")

  defp signup_items_summary([]), do: ""

  defp signup_items_summary(items) do
    items
    |> Enum.map(fn item ->
      name = if item.ticket_type, do: item.ticket_type.name, else: "?"
      "#{item.quantity}× #{name}"
    end)
    |> Enum.join(", ")
  end

  @impl Phoenix.LiveView
  def mount(%{"event_id" => event_id, "release_id" => release_id}, _session, socket) do
    event =
      Events.get_event!(event_id)
      |> Localizer.localize()

    with :ok <- Tiki.Policy.authorize(:event_view, socket.assigns.current_user, event),
         release <- Releases.get_release!(release_id),
         sign_ups <- Releases.get_release_sign_ups(release_id),
         true <- release.event_id == event.id,
         true <- FunWithFlags.enabled?(:releases) do
      if connected?(socket) do
        Releases.subscribe(release_id, sign_ups: true)
      end

      {:ok,
       assign(socket, event: event, release: release)
       |> assign_stats(release, sign_ups)
       |> stream(:sign_ups, sign_ups)}
    else
      _ ->
        {:ok,
         socket
         |> put_flash(:error, gettext("You are not authorized to do that."))
         |> redirect(to: ~p"/admin")}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _uri, socket) do
    %{event: event, release: release} = socket.assigns

    {:noreply,
     assign_breadcrumbs(socket, [
       {"Dashboard", ~p"/admin/"},
       {"Events", ~p"/admin/events"},
       {event.name, ~p"/admin/events/#{event.id}"},
       {"Releases", ~p"/admin/events/#{event.id}/releases"},
       {Localizer.localize(release).name, ~p"/admin/events/#{event}/releases/#{release}"}
     ])}
  end

  @impl Phoenix.LiveView
  def handle_event("seed", %{"id" => signup_id}, socket) do
    with :ok <-
           Tiki.Policy.authorize(:event_manage, socket.assigns.current_user, socket.assigns.event),
         {:ok, _signup} <-
           Releases.seed_signup(signup_id, socket.assigns.current_user.id) do
      {:noreply, socket}
    else
      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, gettext("You are not authorized to do that."))}

      {:error, :invalid_status} ->
        {:noreply, put_flash(socket, :error, gettext("This signup cannot be seeded."))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("reject", %{"id" => signup_id}, socket) do
    with :ok <-
           Tiki.Policy.authorize(:event_manage, socket.assigns.current_user, socket.assigns.event),
         {:ok, _signup} <-
           Releases.reject_signup(signup_id, socket.assigns.current_user.id) do
      {:noreply, socket}
    else
      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, gettext("You are not authorized to do that."))}

      {:error, :invalid_status} ->
        {:noreply, put_flash(socket, :error, gettext("This signup cannot be rejected."))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  @impl true
  def handle_info({:release_updated, release}, socket) do
    sign_ups = Releases.get_release_sign_ups(release.id)
    {:noreply, assign(socket, release: release) |> assign_stats(release, sign_ups)}
  end

  @impl true
  def handle_info({:signup_updated, sign_up}, socket) do
    {:noreply, stream_insert(socket, :sign_ups, sign_up)}
  end

  @impl true
  def handle_info({:signup_deleted, sign_up}, socket) do
    {:noreply, stream_delete(socket, :sign_ups, sign_up)}
  end

  defp assign_stats(socket, release, sign_ups) do
    lottery_end = DateTime.add(release.opens_at, release.signup_window_minutes, :minute)
    purchase_end = DateTime.add(lottery_end, release.purchase_window_minutes, :minute)
    phase = Releases.get_phase(release)
    drawn? = not is_nil(release.drawn_at)

    winners = Enum.filter(sign_ups, &(&1.status in [:drawn, :seeded]))
    paid = Enum.count(winners, &(&1.order && &1.order.status == :paid))

    total_items =
      sign_ups
      |> Enum.flat_map(& &1.items)
      |> Enum.reduce(0, fn item, acc -> acc + item.quantity end)

    assign(socket,
      phase: phase,
      drawn?: drawn?,
      pre_draw: not drawn?,
      lottery_end: lottery_end,
      purchase_end: purchase_end,
      signup_count: length(sign_ups),
      total_items: total_items,
      winner_count: length(winners),
      paid_count: paid
    )
  end
end
