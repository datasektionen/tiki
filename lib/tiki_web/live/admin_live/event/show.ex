defmodule TikiWeb.AdminLive.Event.Show do
  use TikiWeb, :live_view

  alias Tiki.Events
  alias Tiki.Tickets.TicketBatch

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    event = Events.get_event!(id, preload_ticket_types: true)

    batches =
      get_batch_graph(event.ticket_batches)
      |> dbg()

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:batches, batches)
     |> assign(:event, event)}
  end

  defp get_batch_graph(batches) do
    fake_root = %{batch: %TicketBatch{id: 0, name: "fake_root"}}
    graph = :digraph.new()

    batches = Enum.map(batches, fn batch -> %{batch: batch} end)

    IO.inspect(batches)

    for %{batch: %TicketBatch{id: id}} = node <- [fake_root | batches] do
      :digraph.add_vertex(graph, id, node)
    end

    for %{batch: %TicketBatch{id: id, parent_batch_id: parent_id}} <- batches do
      :digraph.add_edge(graph, id, parent_id || fake_root.batch.id)
    end

    :digraph.vertices(graph) |> dbg()
    :digraph.edges(graph) |> dbg()

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

  defp page_title(:show), do: "Show Event"
  defp page_title(:edit), do: "Edit Event"

  attr :batch, :map
  attr :level, :integer, default: 0

  defp ticket_batch(assigns) do
    ~H"""
    <div class="w-full rounded-lg overflow-hidden bg-gray-50 shadow-sm">
      <div class="bg-gray-200 px-4 py-4 flex flex-row justify-between">
        <div>
          <.icon name="hero-tag-mini h-4 w-4" />
          <%= @batch.batch.name %>
        </div>
        <div :if={@batch.batch.max_size}>
          max <%= @batch.batch.max_size %>
        </div>
      </div>
      <div :if={@batch.batch.ticket_types != []} class="flex flex-col gap-4 px-4 py-4">
        <div :for={ticket_type <- @batch.batch.ticket_types} class="flex flex-row justify-between">
          <div>
            <.icon name="hero-ticket-mini h-4 w-4" />
            <%= ticket_type.name %>
          </div>
          <div>
            <%= ticket_type.price %> kr
          </div>
        </div>
      </div>

      <div :if={@batch.children != []} class="flex flex-col gap-4 my-4 mr-2">
        <div :for={child <- @batch.children} class="ml-4">
          <.ticket_batch batch={child} level={@level + 1} />
        </div>
      </div>
    </div>
    """
  end
end
