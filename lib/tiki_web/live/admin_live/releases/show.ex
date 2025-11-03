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
        {gettext("Sign ups: %{release_name}", release_name: Localizer.localize(@release).name)}
      </.card_title>
      <p class="text-muted-foreground text-sm">
        {gettext(
          "All sign ups for this release are listed below. There are %{count} sign ups, and %{total_spots} total spots available. After
          allocating, the top %{total_spots} spots will be allocated tickets. You can drag and drop the sign ups to change the order.",
          count: @streams.sign_ups |> Enum.count(),
          total_spots: @release.ticket_batch.max_size
        )}
      </p>

      <div class="flex flex-row items-center gap-2 sm:col-span-6">
        <.button variant="outline" phx-click="shuffle">
          {gettext("Shuffle")}
        </.button>
        <.button class="ml-auto" variant="default" phx-click="allocate" disabled={@accepted?}>
          {gettext("Allocate")}
        </.button>
        <%!-- <.button navigate={~p"/admin/events/#{@event}/attendees/new"} class="ml-auto">
          {gettext("New attendee")}
        </.button> --%>
      </div>

      <.card class="sm:col-span-6">
        <ul
          id="sign_ups"
          phx-update="stream"
          role="list"
          class="divide-accent divide-y"
          phx-hook="InitSorting"
        >
          <.sign_up_item
            :for={{id, sign_up} <- @streams.sign_ups}
            sign_up={sign_up}
            id={id}
            cutoff={@release.ticket_batch.max_size}
          />
        </ul>
      </.card>
    </div>
    """
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

      {:ok, assign(socket, event: event, release: release) |> stream_sign_ups(sign_ups)}
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
  def handle_event("shuffle", _, socket) do
    with :ok <-
           Tiki.Policy.authorize(:event_manage, socket.assigns.current_user, socket.assigns.event),
         {:ok, sign_ups} <- Releases.shuffle_sign_ups(socket.assigns.release.id) do
      {:noreply, stream_sign_ups(socket, sign_ups, reset: true)}
    else
      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, gettext("You are not authorized to do that."))}

      {:error, reason} ->
        {:noreply, socket |> put_flash(:error, reason)}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("allocate", _, socket) do
    with :ok <-
           Tiki.Policy.authorize(:event_manage, socket.assigns.current_user, socket.assigns.event),
         {:ok, sign_ups} <- Releases.allocate_sign_ups(socket.assigns.release.id) do
      {:noreply, stream_sign_ups(socket, sign_ups, reset: true)}
    else
      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, gettext("You are not authorized to do that."))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, reason)}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("update-sort-order", %{"from" => from, "to" => to}, socket) do
    with :ok <-
           Tiki.Policy.authorize(:event_manage, socket.assigns.current_user, socket.assigns.event),
         {:ok, sign_ups} <-
           Releases.update_sort_order(socket.assigns.release.id, from + 1, to + 1) do
      {:noreply, stream_sign_ups(socket, sign_ups, reset: true)}
    else
      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, gettext("You are not authorized to do that."))}

      {:error, reason} ->
        {:noreply, socket |> put_flash(:error, reason)}
    end
  end

  @impl true
  def handle_info({:release_changed, release}, socket) do
    {:noreply, assign(socket, release: release)}
  end

  @impl true
  def handle_info({:signups_updated, sign_ups}, socket) do
    {:noreply, stream_sign_ups(socket, sign_ups, reset: true)}
  end

  @impl true
  def handle_info({:signup_added, sign_up}, socket) do
    {:noreply, stream_insert(socket, :sign_ups, sign_up)}
  end

  attr :id, :any
  attr :sign_up, :map
  attr :cutoff, :integer
  attr :rest, :global

  defp sign_up_item(assigns) do
    ~H"""
    <li
      id={@id}
      class={[
        "relative flex items-center justify-between gap-x-6 px-2 py-3 first:rounded-t-xl last:rounded-b-xl hover:bg-accent/50 sm:px-2 lg:px-4",
        @sign_up.position - 1 == @cutoff && "border-t-muted-foreground border-t-2",
        @sign_up.status == :accepted && "bg-success-background",
        @sign_up.status == :rejected && "bg-error-background"
      ]}
    >
      <div class="flex w-full items-start gap-x-3">
        <span>#{@sign_up.position}</span>
        <span>{time_to_string(@sign_up.signed_up_at, format: :Hms)}</span>

        <span>{@sign_up.user.full_name}</span>
        <.badge :if={@sign_up.user.year_tag} variant="outline">
          <span class="text-xs">{@sign_up.user.year_tag}</span>
        </.badge>
      </div>
    </li>
    """
  end

  defp stream_sign_ups(socket, sign_ups, opts \\ []) do
    stream(socket, :sign_ups, sign_ups, opts)
    |> assign(accepted?: Enum.any?(sign_ups, fn sign_up -> sign_up.status == :accepted end))
  end
end
