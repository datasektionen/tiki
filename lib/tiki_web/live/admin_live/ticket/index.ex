defmodule TikiWeb.AdminLive.Ticket.Index do
  alias Tiki.Localizer
  use TikiWeb, :live_view

  alias Tiki.Events
  alias Tiki.Tickets.TicketBatch
  alias Tiki.Tickets
  alias Tiki.Tickets.TicketType

  import TikiWeb.Component.Sheet

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {gettext("Tickets")}
        <:subtitle>
          {gettext(
            "Manage the tickets for this event. Each ticket type needs to be assigned to a batch before they can be created."
          )}
        </:subtitle>

        <:actions>
          <.link patch={~p"/admin/events/#{@event}/tickets/batches/new"}>
            <.button variant="secondary">
              {gettext("New batch")}
            </.button>
          </.link>

          <.link patch={~p"/admin/events/#{@event}/tickets/types/new"}>
            <.button variant="secondary">
              {gettext("New ticket type")}
            </.button>
          </.link>
        </:actions>
      </.header>

      <div id="batch-root" class="my-8 flex flex-col gap-4" data-batch="none">
        <.ticket_batch :for={batch <- @batches} batch={batch} />

        <div :if={@batches == []} class="p-4 text-center">
          <.icon name="hero-rectangle-stack-solid" class="text-muted-foreground/20 size-12" />
          <h3 class="text-foreground mt-2 text-sm font-semibold">
            {gettext("No ticket batches")}
          </h3>
          <p class="text-muted-foreground mt-1 text-sm">
            {gettext("Create a new batch to get started.")}
          </p>
          <div class="mt-6">
            <.link :if={@batches == []} patch={~p"/admin/events/#{@event}/tickets/batches/new"}>
              <.button>
                <.icon name="hero-plus" class="size-4 mr-2" />
                {gettext("Create batch")}
              </.button>
            </.link>
          </div>
        </div>
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
  def mount(%{"event_id" => event_id}, _session, socket) do
    event =
      Events.get_event!(event_id, preload_ticket_types: true)
      |> Localizer.localize()

    with :ok <- Tiki.Policy.authorize(:event_view, socket.assigns.current_user, event) do
      {:ok, assign(socket, event: event)}
    else
      {:error, :unauthorized} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("You are not authorized to do that."))
         |> redirect(to: ~p"/admin")}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(params, _session, socket) do
    socket = assign_graph(socket, socket.assigns.event)

    {:noreply,
     socket
     |> assign_breadcrumbs([
       {"Dashboard", ~p"/admin"},
       {"Events", ~p"/admin/events"},
       {socket.assigns.event.name, ~p"/admin/events/#{socket.assigns.event.id}"},
       {"Tickets", ~p"/admin/events/#{socket.assigns.event.id}/tickets"}
     ])
     |> restrict_access(socket.assigns.live_action)
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp restrict_access(socket, action)
       when action in [:edit_batch, :new_batch, :edit_ticket_type, :new_ticket_type] do
    if Tiki.Policy.authorize?(:event_manage, socket.assigns.current_user, socket.assigns.event) do
      socket
    else
      put_flash(socket, :error, gettext("You are not authorized to do that."))
      |> redirect(to: ~p"/admin/events/#{socket.assigns.event.id}/tickets")
    end
  end

  defp restrict_access(socket, _action), do: socket

  def apply_action(socket, :index, _params), do: assign(socket, :page_title, gettext("Tickets"))

  def apply_action(socket, :edit_batch, %{"batch_id" => batch_id}) do
    batch = Tickets.get_ticket_batch!(batch_id)

    if socket.assigns.event.id == batch.event_id do
      socket
      |> assign(:page_title, gettext("Edit Ticket Batch"))
      |> assign(:batch, batch)
    else
      socket
      |> put_flash(:error, gettext("You are not authorized to do that."))
      |> redirect(to: ~p"/admin/events/#{socket.assigns.event.id}/tickets")
    end
  end

  def apply_action(socket, :new_batch, _params) do
    socket
    |> assign(:page_title, gettext("New Ticket Batch"))
    |> assign(:batch, %TicketBatch{event_id: socket.assigns.event.id})
  end

  def apply_action(socket, :edit_ticket_type, %{"ticket_type_id" => tt_id}) do
    ticket_type = Tickets.get_ticket_type!(tt_id)

    if socket.assigns.event.id == ticket_type.ticket_batch.event_id do
      socket
      |> assign(:page_title, gettext("Edit Ticket type"))
      |> assign(:ticket_type, ticket_type)
    else
      socket
      |> put_flash(:error, gettext("You are not authorized to do that."))
      |> redirect(to: ~p"/admin/events/#{socket.assigns.event.id}/tickets")
    end
  end

  def apply_action(socket, :new_ticket_type, params) do
    start_time = socket.assigns.event.start_time

    ticket_type =
      case params do
        %{"batch_id" => batch_id} ->
          %TicketType{ticket_batch_id: batch_id, start_time: start_time}

        _ ->
          %TicketType{start_time: start_time}
      end

    socket
    |> assign(:page_title, gettext("New Ticket type"))
    |> assign(:ticket_type, ticket_type)
  end

  attr :batch, :map

  defp ticket_batch(assigns) do
    ~H"""
    <div
      class="border-border bg-muted/40 w-full overflow-hidden rounded-md text-sm"
      data-batch={@batch.batch.id}
    >
      <.link
        patch={~p"/admin/events/#{@batch.batch.event_id}/tickets/batches/#{@batch.batch}/edit"}
        class="flex flex-row items-center justify-between gap-2 rounded-md p-4 hover:bg-accent"
      >
        <div class="inline-flex items-center gap-2">
          <.icon name="hero-rectangle-stack h-4 w-4" />
          {@batch.batch.name}
        </div>
        <div :if={@batch.batch.max_size} class="text-muted-foreground">
          {"#{@batch.batch.max_size} #{gettext("tickets")}"}
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
                {Localizer.localize(ticket_type).name}
              </div>
              <div class="text-muted-foreground">
                {ticket_type.price} kr
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

      <.link
        class="flex flex-col gap-1 rounded-md p-4 hover:bg-accent"
        patch={
          ~p"/admin/events/#{@batch.batch.event_id}/tickets/types/new?batch_id=#{@batch.batch.id}"
        }
      >
        <div class="text-foreground inline-flex items-center gap-2 rounded-md text-sm">
          <.icon name="hero-plus-circle" class="size-4 ml-[1px]" />
          {gettext("Add ticket")}
        </div>
      </.link>
    </div>
    """
  end

  defp assign_graph(socket, event) do
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

  @impl true
  def handle_info({ref, {result, from, to}}, socket) do
    Process.demonitor(ref, [:flush])

    send_update(TikiWeb.AdminLive.Ticket.TicketTypeFormComponent,
      id: "batch-form-component",
      translate_result: result,
      from: from,
      to: to
    )

    {:noreply, socket}
  end
end
