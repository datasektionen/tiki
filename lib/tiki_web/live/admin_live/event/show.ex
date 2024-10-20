defmodule TikiWeb.AdminLive.Event.Show do
  use TikiWeb, :live_view

  alias Tiki.Tickets.TicketType
  alias Tiki.Tickets
  alias Tiki.Events
  alias Tiki.Tickets.TicketBatch

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _, socket) do
    event = Events.get_event!(id, preload_ticket_types: true)
    batches = get_batch_graph(event.ticket_batches)

    {:noreply,
     socket
     |> assign(:batches, batches)
     |> assign(:event, event)
     |> apply_action(socket.assigns.live_action, params)}
  end

  def apply_action(socket, :show, _params) do
    assign(socket, :page_title, "Show Event")
    |> assign(:breadcrumbs, [
      {"Dashboard", ~p"/admin"},
      {"Events", ~p"/admin/events"},
      {socket.assigns.event.name, ~p"/admin/events/#{socket.assigns.event.id}"}
    ])
  end

  def apply_action(socket, :edit, _params), do: assign(socket, :page_title, "Edit Event")

  def apply_action(socket, :edit_batch, %{"batch_id" => batch_id}) do
    batch = Tickets.get_ticket_batch!(batch_id)

    socket
    |> assign(:page_title, "Edit Ticket Batch")
    |> assign(:batch, batch)
  end

  def apply_action(socket, :new_batch, _params) do
    socket
    |> assign(:page_title, "New Ticket Batch")
    |> assign(:batch, %TicketBatch{event_id: socket.assigns.event.id})
  end

  def apply_action(socket, :edit_ticket_type, %{"ticket_type_id" => tt_id}) do
    ticket_type = Tickets.get_ticket_type!(tt_id)

    socket
    |> assign(:page_title, "Edit Ticket type")
    |> assign(:ticket_type, ticket_type)
  end

  def apply_action(socket, :new_ticket_type, _params) do
    socket
    |> assign(:page_title, "New Ticket type")
    |> assign(:ticket_type, %TicketType{})
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
    <div class="w-full overflow-hidden rounded-lg bg-gray-50 shadow-sm">
      <.link
        patch={~p"/admin/events/#{@batch.batch.event_id}/batches/#{@batch.batch}/edit"}
        phx-click={JS.push_focus()}
        class="flex flex-row justify-between bg-gray-200 px-4 py-4 hover:bg-gray-300"
      >
        <div class="inline-flex items-center gap-2">
          <.icon name="hero-rectangle-stack-mini h-4 w-4" />
          <%= @batch.batch.name %>
        </div>
        <div :if={@batch.batch.max_size}>
          max <%= @batch.batch.max_size %>
        </div>
      </.link>
      <div :if={@batch.batch.ticket_types != []} class="flex flex-col">
        <.link
          :for={ticket_type <- @batch.batch.ticket_types}
          patch={~p"/admin/events/#{@batch.batch.event_id}/ticket-types/#{ticket_type}/edit"}
          class="flex flex-row justify-between px-4 py-4 hover:bg-white"
        >
          <div class="inline-flex items-center gap-2">
            <.icon name="hero-ticket-mini h-4 w-4" />
            <%= ticket_type.name %>
          </div>
          <div class="text-gray-500">
            <%= ticket_type.price %> kr
          </div>
        </.link>
      </div>

      <div :if={@batch.children != []} class="my-4 mr-2 flex flex-col gap-4">
        <div :for={child <- @batch.children} class="ml-4">
          <.ticket_batch batch={child} level={@level + 1} />
        </div>
      </div>
    </div>
    """
  end
end
