defmodule TikiWeb.AdminLive.Ticket.Index do
  use TikiWeb, :live_view

  alias Tiki.Events
  alias Tiki.Tickets.TicketBatch
  alias Tiki.Tickets
  alias Tiki.Tickets.TicketType

  import TikiWeb.Component.Sheet

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="my-8">
      <div class="mb-4 flex flex-row items-center justify-between">
        <div>
          <h2 class="mb-2 text-lg font-bold">
            <%= gettext("Tickets") %>
          </h2>
          <div class="text-muted-foreground text-sm">
            <%= gettext(
              "Manage the tickets for this event. Each ticket type needs to be assigned to a batch before they can be created."
            ) %>
          </div>
        </div>

        <div class="flex flex-row justify-end gap-2">
          <.link patch={~p"/admin/events/#{@event}/tickets/batches/new"}>
            <.button variant="secondary">
              <%= gettext("New batch") %>
            </.button>
          </.link>

          <.link patch={~p"/admin/events/#{@event}/tickets/types/new"}>
            <.button variant="secondary">
              <%= gettext("New ticket type") %>
            </.button>
          </.link>
        </div>
      </div>

      <div id="batch-root" class="my-8 flex flex-col gap-4" data-batch="none">
        <.ticket_batch :for={batch <- @batches} batch={batch} />
      </div>

      <.sheet :if={@live_action in [:new_batch, :edit_batch]} class="">
        <.sheet_content
          show
          id="batch-sheet"
          side="right"
          class="w-full"
          on_cancel={JS.navigate(~p"/admin/events/#{@event}/tickets")}
        >
          <.live_component
            id="batch-form-component"
            module={TikiWeb.AdminLive.Ticket.BatchFormComponent}
            batch={@batch}
            event={@event}
            action={@live_action}
          />
        </.sheet_content>
      </.sheet>

      <.sheet :if={@live_action in [:new_ticket_type, :edit_ticket_type]} class="">
        <.sheet_content
          show
          id="batch-sheet"
          side="right"
          class="w-full"
          on_cancel={JS.navigate(~p"/admin/events/#{@event}/tickets")}
        >
          <.live_component
            id="batch-form-component"
            module={TikiWeb.AdminLive.Ticket.TicketTypeFormComponent}
            ticket_type={@ticket_type}
            event={@event}
            action={@live_action}
          />
        </.sheet_content>
      </.sheet>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"id" => event_id} = params, _session, socket) do
    socket = assign_graph(socket, event_id)

    {:noreply,
     socket
     |> assign_breadcrumbs([
       {"Dashboard", ~p"/admin"},
       {"Events", ~p"/admin/events"},
       {socket.assigns.event.name, ~p"/admin/events/#{socket.assigns.event.id}"},
       {"Tickets", ~p"/admin/events/#{socket.assigns.event.id}/tickets"}
     ])
     |> apply_action(socket.assigns.live_action, params)}
  end

  def apply_action(socket, :index, _params), do: assign(socket, :page_title, gettext("Tickets"))

  def apply_action(socket, :edit_batch, %{"batch_id" => batch_id}) do
    batch = Tickets.get_ticket_batch!(batch_id)

    socket
    |> assign(:page_title, gettext("Edit Ticket Batch"))
    |> assign(:batch, batch)
  end

  def apply_action(socket, :new_batch, _params) do
    socket
    |> assign(:page_title, gettext("New Ticket Batch"))
    |> assign(:batch, %TicketBatch{event_id: socket.assigns.event.id})
  end

  def apply_action(socket, :edit_ticket_type, %{"ticket_type_id" => tt_id}) do
    ticket_type = Tickets.get_ticket_type!(tt_id)

    socket
    |> assign(:page_title, gettext("Edit Ticket type"))
    |> assign(:ticket_type, ticket_type)
  end

  def apply_action(socket, :new_ticket_type, _params) do
    socket
    |> assign(:page_title, gettext("New Ticket type"))
    |> assign(:ticket_type, %TicketType{})
  end

  attr :batch, :map

  defp ticket_batch(assigns) do
    ~H"""
    <div
      class="border-border bg-muted/40 w-full overflow-hidden rounded-md pb-4"
      data-batch={@batch.batch.id}
    >
      <.link
        patch={~p"/admin/events/#{@batch.batch.event_id}/tickets/batches/#{@batch.batch}/edit"}
        class="flex flex-row items-center justify-between gap-2 rounded-md p-4 hover:bg-accent"
      >
        <div class="inline-flex items-center gap-2">
          <.icon name="hero-rectangle-stack h-4 w-4" />
          <%= @batch.batch.name %>
        </div>
        <div :if={@batch.batch.max_size} class="text-muted-foreground">
          <%= "#{@batch.batch.max_size} #{gettext("tickets")}" %>
        </div>
      </.link>

      <div
        :if={@batch.batch.ticket_types != []}
        class="flex flex-col pl-4"
        id={"batch-zone-#{@batch.batch.id}"}
        data-batch={@batch.batch.id}
      >
        <.link
          :for={ticket_type <- @batch.batch.ticket_types |> Enum.sort_by(&{&1.price, &1.name})}
          patch={~p"/admin/events/#{@batch.batch.event_id}/tickets/types/#{ticket_type}/edit"}
          class="ml-2 border-l"
          data-ticket-type={ticket_type.id}
        >
          <div class="-ml-[1px] border-foreground flex flex-col border-l pl-2">
            <div class="text-foreground inline-flex items-center gap-2 rounded-md p-4 hover:bg-accent">
              <div class="inline-flex items-center gap-2">
                <.icon name="hero-ticket h-4 w-4" />
                <%= ticket_type.name %>
              </div>
              <div class="text-muted-foreground">
                <%= ticket_type.price %> kr
              </div>
            </div>
          </div>
        </.link>
      </div>

      <div
        :if={@batch.children != []}
        class="flex flex-col pl-4"
        id={"batch-zone-#{@batch.batch.id}-children"}
        data-batch={@batch.batch.id}
      >
        <div
          :for={child <- @batch.children |> Enum.sort_by(& &1.batch.name)}
          class="ml-2 border-l"
          data-batch={child.batch.id}
        >
          <div class="-ml-[1px] border-foreground flex flex-col border-l pl-2">
            <div class="text-foreground inline-flex items-center gap-2 rounded-md">
              <.ticket_batch batch={child} />
            </div>
          </div>
        </div>
      </div>

      <div
        :if={@batch.batch.ticket_types == [] && @batch.children == []}
        id={"batch-zone-#{@batch.batch.id}-no-children"}
        data-batch={@batch.batch.id}
        class="flex flex-col gap-1 px-4"
      >
        <div class="ml-2 border-l">
          <div class="-ml-[1px] border-foreground flex flex-col border-l pl-2">
            <div class="text-muted-foreground inline-flex items-center gap-2 rounded-md p-2">
              <%= gettext("No tickets") %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp assign_graph(socket, event_id) do
    event = Events.get_event!(event_id, preload_ticket_types: true)
    batches = get_batch_graph(event.ticket_batches)

    assign(socket, event: event, batches: batches)
  end

  defp get_batch_graph(batches) do
    fake_root = %{batch: %TicketBatch{id: 0, name: "fake_root"}}
    graph = :digraph.new()

    batches = Enum.map(batches, fn batch -> %{batch: batch} end)

    for %{batch: %TicketBatch{id: id}} = node <- [fake_root | batches] do
      :digraph.add_vertex(graph, id, node)
    end

    for %{batch: %TicketBatch{id: id, parent_batch_id: parent_id}} <- batches do
      :digraph.add_edge(graph, id, parent_id || fake_root.batch.id)
    end

    :digraph.vertices(graph)
    :digraph.edges(graph)

    %{children: batches} = build_graph(graph, fake_root.batch.id)

    :digraph.delete(graph)

    batches
  end

  defp build_graph(graph, node) do
    children =
      for child <- :digraph.in_neighbours(graph, node) do
        build_graph(graph, child)
      end

    {^node, label} = :digraph.vertex(graph, node)

    Map.put(label, :children, children)
  end
end
