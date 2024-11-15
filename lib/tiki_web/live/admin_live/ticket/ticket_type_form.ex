defmodule TikiWeb.AdminLive.Ticket.TicketTypeForm do
  use TikiWeb, :live_view

  alias Tiki.Tickets
  alias Tiki.Tickets.TicketType

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @page_title %>
        <:subtitle>Use this form to manage ticket type records in your database.</:subtitle>
      </.header>

      <.simple_form for={@form} id="ticket_type-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label={gettext("Name")} />
        <.input field={@form[:description]} type="textarea" label={gettext("Description")} />
        <.input field={@form[:purchasable]} type="checkbox" label={gettext("Purchasable")} />
        <.input field={@form[:price]} type="number" label={gettext("Price")} />
        <.input field={@form[:release_time]} type="datetime-local" label={gettext("Release time")} />
        <.input
          field={@form[:expire_time]}
          type="datetime-local"
          label={gettext("Purchase deadline")}
        />

        <.input
          field={@form[:ticket_batch_id]}
          type="select"
          label={gettext("Ticket batch")}
          options={options_for_batch(@event.ticket_batches)}
        />
        <.input field={@form[:promo_code]} type="text" label={gettext("Promo code")} />

        <:actions>
          <div>
            <.button phx-disable-with={gettext("Saving...")}>
              <%= gettext("Save ticket type") %>
            </.button>
            <.button
              :if={@live_action == :edit}
              type="button"
              phx-click="delete"
              phx-disable-with={gettext("Deleting...")}
              class="bg-red-700 hover:bg-red-900"
              data-confirm={gettext("Are you sure?")}
            >
              <%= gettext("Delete ticket type") %>
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

    {:ok, assign(socket, event: event) |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"ticket_type_id" => id}) do
    ticket_type = Tickets.get_ticket_type!(id)

    socket
    |> assign(:page_title, gettext("Edit ticket type"))
    |> assign(:ticket_type, ticket_type)
    |> assign(:form, to_form(Tickets.change_ticket_type(ticket_type)))
    |> assign_breadcrumbs([
      {"Dashboard", ~p"/admin"},
      {"Events", ~p"/admin/events"},
      {socket.assigns.event.name, ~p"/admin/events/#{socket.assigns.event.id}"},
      {"Tickets", ~p"/admin/events/#{socket.assigns.event.id}/tickets"},
      {"Edit ticket type",
       ~p"/admin/events/#{socket.assigns.event.id}/tickets/types/#{ticket_type.id}/edit"}
    ])
  end

  defp apply_action(socket, :new, _params) do
    ticket_type = %TicketType{}

    socket
    |> assign(:page_title, gettext("Edit ticket type"))
    |> assign(:ticket_type, ticket_type)
    |> assign(:form, to_form(Tickets.change_ticket_type(ticket_type)))
    |> assign_breadcrumbs([
      {"Dashboard", ~p"/admin"},
      {"Events", ~p"/admin/events"},
      {socket.assigns.event.name, ~p"/admin/events/#{socket.assigns.event.id}"},
      {"Tickets", ~p"/admin/events/#{socket.assigns.event.id}/tickets"},
      {"New ticket type", ~p"/admin/events/#{socket.assigns.event.id}/tickets/types/new"}
    ])
  end

  @impl true
  def handle_event("validate", %{"ticket_type" => ticket_type_params}, socket) do
    changeset =
      socket.assigns.ticket_type
      |> Tickets.change_ticket_type(ticket_type_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"ticket_type" => ticket_type_params}, socket) do
    save_ticket_type(socket, socket.assigns.live_action, ticket_type_params)
  end

  def handle_event("delete", _, socket) do
    {:ok, _} = Tickets.delete_ticket_type(socket.assigns.ticket_type)

    {:noreply,
     socket
     |> put_flash(:info, gettext("Ticket type deleted successfully"))
     |> push_navigate(to: return_path(socket.assigns.event))}
  end

  defp save_ticket_type(socket, :edit, ticket_type_params) do
    case Tickets.update_ticket_type(socket.assigns.ticket_type, ticket_type_params) do
      {:ok, _ticket_type} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Ticket type updated successfully"))
         |> push_navigate(to: return_path(socket.assigns.event))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_ticket_type(socket, :new, ticket_type_params) do
    case Tickets.create_ticket_type(ticket_type_params) do
      {:ok, _ticket_type} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Ticket type created successfully"))
         |> push_navigate(to: return_path(socket.assigns.event))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp return_path(event), do: ~p"/admin/events/#{event}/tickets"

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp options_for_batch(batches),
    do: Enum.map(batches, fn batch -> {batch.name, batch.id} end)
end
