defmodule TikiWeb.AdminLive.Event.TicketTypeFormComponent do
  use TikiWeb, :live_component

  alias Tiki.Tickets

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage ticket type records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="ticket_type-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Namn" />
        <.input field={@form[:description]} type="textarea" label="Beskrivning" />
        <.input field={@form[:purchasable]} type="checkbox" label="Köpbar" />
        <.input field={@form[:price]} type="number" label="Pris" />
        <.input field={@form[:release_time]} type="datetime-local" label="Släpps" />
        <.input field={@form[:expire_time]} type="datetime-local" label="Utgår" />

        <.input
          field={@form[:ticket_batch_id]}
          type="select"
          label="Ticket batch"
          options={options_for_batch(@batches)}
        />

        <:actions>
          <div>
            <.button phx-disable-with="Saving...">Save ticket type</.button>
            <.button
              :if={@action == :edit_batch}
              type="button"
              phx-click="delete"
              phx-disable-with="Deleting..."
              class="bg-red-700 hover:bg-red-900"
              phx-target={@myself}
              data-confirm="Are you sure?"
            >
              Delete ticket type
            </.button>
          </div>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{ticket_type: ticket_type} = assigns, socket) do
    changeset = Tickets.change_ticket_type(ticket_type)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
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
    save_ticket_type(socket, socket.assigns.action, ticket_type_params)
  end

  def handle_event("delete", _, socket) do
    {:ok, _} = Tickets.delete_ticket_type(socket.assigns.ticket_type)

    notify_parent({:deleted, socket.assigns.ticket_type})

    {:noreply,
     socket
     |> put_flash(:info, "Ticket type deleted successfully")
     |> push_patch(to: socket.assigns.patch)}
  end

  defp save_ticket_type(socket, :edit_ticket_type, ticket_type_params) do
    case Tickets.update_ticket_type(socket.assigns.ticket_type, ticket_type_params) do
      {:ok, ticket_type} ->
        notify_parent({:saved, ticket_type})

        {:noreply,
         socket
         |> put_flash(:info, "Ticket type updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_ticket_type(socket, :new_ticket_type, ticket_type_params) do
    case Tickets.create_ticket_type(ticket_type_params) do
      {:ok, ticket_type} ->
        notify_parent({:saved, ticket_type})

        {:noreply,
         socket
         |> put_flash(:info, "Ticket type created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp options_for_batch(batches),
    do: Enum.map(batches, fn batch -> {batch.name, batch.id} end)
end
