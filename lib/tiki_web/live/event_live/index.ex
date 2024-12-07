defmodule TikiWeb.EventLive.Index do
  use TikiWeb, :live_view

  alias Tiki.Events

  def render(assigns) do
    ~H"""
    <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      <.link :for={event <- @events} navigate={~p"/events/#{event}"} class="">
        <div class="w-full space-y-3">
          <div class="relative overflow-hidden rounded-lg">
            <img
              src={event.image_url}
              class="aspect-[16/9] h-full w-full rounded-md object-cover"
              alt={event.name}
              loading="lazy"
            />
            <div class="absolute top-2 right-2 flex items-start justify-end">
              <div class="bg-zinc-900/80 rounded-full px-2 py-1 text-sm text-white">
                <time time={event.event_date}>
                  {time_to_string(event.event_date)}
                </time>
                <span class="sr-only">.</span>
              </div>
            </div>
          </div>
          <div class="flex gap-2">
            <div class="grow space-y-2">
              <p class="text-foreground font-medium leading-none">
                <span aria-hidden="true">
                  {event.name}
                </span>
              </p>
              <div class="text-muted-foreground flex items-center gap-1 text-sm">
                <.icon name="hero-map-pin" class="size-4" />
                <span class="sr-only">{gettext("Location")}</span>
                <div class="grow leading-none">{event.location}</div>
              </div>
            </div>
          </div>
        </div>
      </.link>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    events =
      Events.list_events()
      |> Enum.sort_by(& &1.event_date, {:asc, NaiveDateTime})

    {:ok, assign(socket, events: events)}
  end
end
