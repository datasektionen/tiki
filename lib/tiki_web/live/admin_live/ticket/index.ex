defmodule TikiWeb.AdminLive.Ticket.Index do
  use TikiWeb, :live_view

  alias Tiki.Events
  alias Tiki.Tickets.TicketBatch
  alias Tiki.Tickets
  alias Tiki.Tickets.TicketType

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

  @impl Phoenix.LiveView
  def handle_event("drop", %{"batch" => batch_id, "to" => %{"batch" => parent_batch_id}}, socket) do
    ticket_batch = Tickets.get_ticket_batch!(batch_id)

    parent_batch_id =
      if parent_batch_id == "none", do: nil, else: String.to_integer(parent_batch_id)

    if parent_batch_id == ticket_batch.id do
      {:noreply, socket}
    else
      Tickets.update_ticket_batch(ticket_batch, %{"parent_batch_id" => parent_batch_id})

      {:noreply, assign_graph(socket, socket.assigns.event.id)}
    end
  end

  def handle_event("drop", %{"ticketType" => tt_id, "to" => %{"batch" => batch_id}}, socket) do
    ticket_type = Tickets.get_ticket_type!(tt_id)

    Tickets.update_ticket_type(ticket_type, %{"ticket_batch_id" => batch_id})

    {:noreply, assign_graph(socket, socket.assigns.event.id)}
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

  attr :batch, :map
  attr :level, :integer, default: 0

  defp ticket_batch(assigns) do
    ~H"""
    <div
      class="bg-accent/50 border-border w-full overflow-hidden rounded-lg border shadow-sm"
      data-batch={@batch.batch.id}
    >
      <.link
        patch={~p"/admin/events/#{@batch.batch.event_id}/tickets/batches/#{@batch.batch}/edit"}
        phx-click={JS.push_focus()}
        class="bg-accent/50 flex flex-row justify-between px-4 py-4 hover:bg-accent"
      >
        <div class="inline-flex items-center gap-2">
          <.icon name="hero-rectangle-stack-mini h-4 w-4" />
          <%= @batch.batch.name %>
        </div>
        <div :if={@batch.batch.max_size}>
          max <%= @batch.batch.max_size %>
        </div>
      </.link>
      <div
        :if={@batch.batch.ticket_types != []}
        class="flex flex-col"
        id={"batch-zone-#{@batch.batch.id}"}
        phx-hook="Sortable"
        data-batch={@batch.batch.id}
      >
        <.link
          :for={ticket_type <- @batch.batch.ticket_types}
          patch={~p"/admin/events/#{@batch.batch.event_id}/tickets/types/#{ticket_type}/edit"}
          class="flex flex-row justify-between px-4 py-4 hover:bg-accent"
          data-ticket-type={ticket_type.id}
        >
          <div class="inline-flex items-center gap-2">
            <.icon name="hero-ticket-mini h-4 w-4" />
            <%= ticket_type.name %>
          </div>
          <div class="text-muted-foreground">
            <%= ticket_type.price %> kr
          </div>
        </.link>
      </div>

      <div
        :if={@batch.children != []}
        class="my-4 mr-2 flex flex-col gap-4"
        id={"batch-zone-#{@batch.batch.id}-children"}
        phx-hook="Sortable"
        data-batch={@batch.batch.id}
      >
        <div :for={child <- @batch.children} class="ml-4" data-batch={child.batch.id}>
          <.ticket_batch batch={child} level={@level + 1} />
        </div>
      </div>

      <div
        :if={@batch.batch.ticket_types == [] && @batch.children == []}
        id={"batch-zone-#{@batch.batch.id}-no-children"}
        phx-hook="Sortable"
        data-batch={@batch.batch.id}
        class="flex flex-col justify-between px-4 py-4 hover:bg-background"
      >
        <%= gettext("No tickets") %>
      </div>
    </div>
    """
  end
end
