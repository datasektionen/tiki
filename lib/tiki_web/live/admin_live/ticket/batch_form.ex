defmodule TikiWeb.AdminLive.Ticket.BatchForm do
  use TikiWeb, :live_view

  alias Tiki.Tickets
  alias Tiki.Tickets.TicketBatch

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @page_title %>
        <:subtitle>
          <%= gettext("Manage a ticket batch for this event.") %>
        </:subtitle>
      </.header>

      <.simple_form for={@form} id="batch-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label={gettext("Name")} />
        <.input field={@form[:max_size]} type="number" label={gettext("Number of tickets")} />
        <.input
          field={@form[:parent_batch_id]}
          type="select"
          label="Parent batch"
          options={options_for_parent_batch(@event.ticket_batches, @batch)}
          prompt={gettext("None")}
        />

        <:actions>
          <div>
            <.button phx-disable-with={gettext("Saving...")}>
              <%= gettext("Save batch") %>
            </.button>
            <.button
              :if={@live_action == :edit}
              type="button"
              phx-click="delete"
              phx-disable-with={gettext("Deleting...")}
              class="bg-red-700 hover:bg-red-900"
              data-confirm={gettext("Are you sure?")}
            >
              <%= gettext("Delete batch") %>
            </.button>
          </div>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def mount(%{"id" => event_id} = params, _session, socket) do
    event = Tiki.Events.get_event!(event_id, preload_ticket_types: true)

    {:ok,
     assign(socket, event: event)
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"batch_id" => id}) do
    batch = Tickets.get_ticket_batch!(id)

    socket
    |> assign(:page_title, gettext("Edit batch"))
    |> assign(:batch, batch)
    |> assign(:form, to_form(Tickets.change_ticket_batch(batch)))
    |> assign_breadcrumbs([
      {"Dashboard", ~p"/admin"},
      {"Events", ~p"/admin/events"},
      {socket.assigns.event.name, ~p"/admin/events/#{socket.assigns.event.id}"},
      {"Tickets", ~p"/admin/events/#{socket.assigns.event.id}/tickets"},
      {"Edit batch",
       ~p"/admin/events/#{socket.assigns.event.id}/tickets/batches/#{batch.id}/edit"}
    ])
  end

  defp apply_action(socket, :new, _params) do
    batch = %TicketBatch{}

    socket
    |> assign(:page_title, gettext("New batch"))
    |> assign(:batch, batch)
    |> assign(:form, to_form(Tickets.change_ticket_batch(batch)))
    |> assign_breadcrumbs([
      {"Dashboard", ~p"/admin"},
      {"Events", ~p"/admin/events"},
      {socket.assigns.event.name, ~p"/admin/events/#{socket.assigns.event.id}"},
      {"Tickets", ~p"/admin/events/#{socket.assigns.event.id}/tickets"},
      {"New batch", ~p"/admin/events/#{socket.assigns.event.id}/tickets/batches/new"}
    ])
  end

  @impl true
  def handle_event("validate", %{"ticket_batch" => batch_params}, socket) do
    changeset =
      socket.assigns.batch
      |> Tickets.change_ticket_batch(batch_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"ticket_batch" => batch_params}, socket) do
    save_batch(socket, socket.assigns.live_action, batch_params)
  end

  def handle_event("delete", _, socket) do
    {:ok, _} = Tickets.delete_ticket_batch(socket.assigns.batch)

    {:noreply,
     socket
     |> put_flash(:info, gettext("Batch deleted successfully"))
     |> push_navigate(to: return_path(socket.assigns.event))}
  end

  defp save_batch(socket, :edit, batch_params) do
    case Tickets.update_ticket_batch(socket.assigns.batch, batch_params) do
      {:ok, _batch} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Batch updated successfully"))
         |> push_navigate(to: return_path(socket.assigns.event))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_batch(socket, :new, batch_params) do
    batch_params = Map.put(batch_params, "event_id", socket.assigns.event.id)

    case Tickets.create_ticket_batch(batch_params) do
      {:ok, _batch} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Batch created successfully"))
         |> push_navigate(to: return_path(socket.assigns.event))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         assign_form(socket, changeset) |> put_flash(:error, gettext("Something went wrong"))}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp options_for_parent_batch(batches, batch),
    do:
      Enum.map(batches, fn batch -> {batch.name, batch.id} end)
      |> Enum.reject(fn {_, id} -> id == batch.id end)

  defp return_path(event), do: ~p"/admin/events/#{event}/tickets"
end
