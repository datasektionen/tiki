defmodule TikiWeb.EventLive.Index do
  use TikiWeb, :live_view

  alias Tiki.Events
  import TikiWeb.Component.DropdownMenu
  import TikiWeb.Component.Menu

  def render(assigns) do
    ~H"""
    <.header>{gettext("Public events")}</.header>
    <div class="flex flex-row items-center gap-1 pb-4">
      <.dropdown_menu id="date-dropdown">
        <.dropdown_menu_trigger>
          <.button variant="outline" size="sm" class="h-8 gap-1">
            <.icon name="hero-calendar-date-range" class="h-3.5 w-3.5" />
            <span class="sr-only sm:not-sr-only sm:whitespace-nowrap">
              {gettext("Dates")}
            </span>
          </.button>
        </.dropdown_menu_trigger>
        <.dropdown_menu_content>
          <.menu class="">
            <.menu_label>
              {gettext("Event dates")}
            </.menu_label>

            <.menu_separator />
            <.menu_item
              phx-click={JS.push("filter", value: %{date: "upcoming"})}
              class={@params["date"] == "upcoming" && "bg-accent"}
            >
              {gettext("Upcoming")}
            </.menu_item>
            <.menu_item
              phx-click={JS.push("filter", value: %{date: "past"})}
              class={@params["date"] == "past" && "bg-accent"}
            >
              {gettext("Past")}
            </.menu_item>
          </.menu>
        </.dropdown_menu_content>
      </.dropdown_menu>
      <.dropdown_menu id="sort-by" class="mr-0 ml-auto">
        <.dropdown_menu_trigger>
          <.button variant="outline" size="sm" class="h-8 gap-1">
            <.icon name="hero-arrows-up-down" class="h-3.5 w-3.5" />
            <span class="sr-only sm:not-sr-only sm:whitespace-nowrap">
              {gettext("Sort by")}
            </span>
          </.button>
        </.dropdown_menu_trigger>
        <.dropdown_menu_content align="end" class="min-w-[10rem]">
          <.menu class="">
            <.menu_label>
              {gettext("Sort by")}
            </.menu_label>

            <.menu_separator />
            <.menu_item
              phx-click={JS.push("filter", value: %{sort: "date"})}
              class={@params["sort"] == "date" && "bg-accent"}
            >
              {gettext("Date (oldest first)")}
            </.menu_item>
            <.menu_item
              phx-click={JS.push("filter", value: %{sort: "date_desc"})}
              class={@params["sort"] == "date_desc" && "bg-accent"}
            >
              {gettext("Date (newest first)")}
            </.menu_item>
            <.menu_item
              phx-click={JS.push("filter", value: %{sort: "popularity"})}
              class={@params["sort"] == "popularity" && "bg-accent"}
            >
              {gettext("Popularity")}
            </.menu_item>
          </.menu>
        </.dropdown_menu_content>
      </.dropdown_menu>
    </div>

    <div class=" grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      <.link :for={event <- @events} navigate={~p"/events/#{event}"} class="">
        <div class="w-full space-y-3">
          <div class="relative overflow-hidden rounded-lg">
            <img
              src={image_url(event.image_url, width: 600)}
              class="aspect-[16/9] h-full w-full rounded-md object-cover"
              alt={event.name}
              loading="lazy"
            />
            <div class="absolute top-2 right-2 flex items-start justify-end">
              <div class="bg-zinc-900/80 rounded-full px-2 py-1 text-sm text-white">
                <time time={event.start_time}>
                  {time_to_string(event.start_time)}
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

    <div :if={@events == []} class="flex flex-col items-center">
      <.icon name="hero-sparkles-solid" class="text-muted-foreground/20 size-12" />
      <h3 class="text-foreground mt-2 text-sm font-semibold">
        {gettext("No events found")}
      </h3>
      <p class="text-muted-foreground mt-1 text-sm">
        {gettext("Try adjusting your filters or check back later.")}
      </p>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(params, _url, socket) do
    params = parse_params(params)

    events = Events.list_public_events(filters: filters(params), sort_by: sort(params))

    {:noreply, assign(socket, params: params, events: events)}
  end

  defp parse_params(params) do
    %{"date" => "upcoming", "sort" => "date"}
    |> Map.merge(Map.take(params, ["date", "sort"]))
  end

  defp filters(params) do
    Map.take(params, ["date"])
    |> Enum.map(&param_to_filters/1)
    |> Enum.reduce(fn f1, f2 -> {:and, f1, f2} end)
  end

  defp sort(params) do
    case Map.get(params, "sort", "date") do
      "popularity" -> :popularity
      "date_desc" -> [desc: :start_time]
      _ -> [asc: :start_time]
    end
  end

  defp param_to_filters({"date", "past"}),
    do:
      {:or, {:end_time, DateTime.utc_now(), :lt},
       {:and, {:start_time, DateTime.utc_now(), :lt}, {:end_time, :is_nil}}}

  defp param_to_filters({"date", _}),
    do: {:or, {:start_time, DateTime.utc_now(), :gt}, {:end_time, DateTime.utc_now(), :gt}}

  def handle_event("filter", %{"date" => date}, socket) do
    url = self_path(socket, :index, %{"date" => date})

    {:noreply, push_patch(socket, to: url)}
  end

  def handle_event("filter", %{"sort" => sort}, socket) do
    url = self_path(socket, :index, %{"sort" => sort})

    {:noreply, push_patch(socket, to: url)}
  end

  defp self_path(socket, action, extra) do
    TikiWeb.Router.Helpers.event_index_path(
      socket,
      action,
      Enum.into(extra, socket.assigns.params)
    )
  end
end
