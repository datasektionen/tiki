defmodule TikiWeb.AdminLive.Ticket.TicketTypeFormComponent do
  use TikiWeb, :live_component

  alias Tiki.Tickets

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= title(@action) %>
        <:subtitle>Use this form to manage ticket type records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="ticket_type-form"
        phx-change="validate"
        phx-submit="save"
        phx-target={@myself}
      >
        <.input field={@form[:name]} type="text" label={gettext("Name")} />
        <.input field={@form[:description]} type="textarea" label={gettext("Description")} />
        <.input field={@form[:start_time]} type="datetime-local" label={gettext("Start time")} />
        <.input field={@form[:end_time]} type="datetime-local" label={gettext("End time")} />

        <.input
          field={@form[:form_id]}
          type="select"
          label={gettext("Signup form")}
          options={options_for_forms(@forms)}
          default={@event.default_form_id}
        />
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
              :if={@action == :edit_ticket_type}
              type="button"
              phx-target={@myself}
              phx-click="delete"
              variant="destructive"
              phx-disable-with={gettext("Deleting...")}
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
  def update(assigns, socket) do
    changeset = Tickets.change_ticket_type(assigns.ticket_type)
    forms = Tiki.Forms.list_forms_for_event(assigns.event.id)

    {:ok,
     assign(socket, assigns)
     |> assign(:forms, forms)
     |> assign(form: to_form(changeset))}
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

    {:noreply,
     socket
     |> put_flash(:info, gettext("Ticket type deleted successfully"))
     |> push_navigate(to: return_path(socket.assigns.event))}
  end

  defp save_ticket_type(socket, :edit_ticket_type, ticket_type_params) do
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

  defp save_ticket_type(socket, :new_ticket_type, ticket_type_params) do
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

  defp options_for_forms(forms) do
    Enum.map(forms, fn form -> {form.name, form.id} end)
  end

  defp title(:edit_ticket_type), do: gettext("Edit ticket type")
  defp title(:new_ticket_type), do: gettext("New ticket type")
end
