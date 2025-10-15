defmodule TikiWeb.AdminLive.Ticket.BatchFormComponent do
  use TikiWeb, :live_component

  alias Tiki.Tickets

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {title(@action)}
        <:subtitle>
          {gettext(
            "Manage a ticket batch for this event. Ticket batches are not visible to the public, but can be used to group ticket types together, and set group limits. Ticket batches can be arbitrarily nested."
          )}
        </:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="batch-form"
        phx-change="validate"
        phx-submit="save"
        phx-target={@myself}
      >
        <.input field={@form[:name]} type="text" label={gettext("Name")} />
        <.input field={@form[:max_size]} type="number" label={gettext("Number of tickets")} />
        <.input
          field={@form[:parent_batch_id]}
          type="select"
          label={gettext("Parent batch")}
          options={options_for_parent_batch(@event.ticket_batches, @batch)}
          prompt={gettext("None")}
        />

        <:actions>
          <div>
            <.button phx-disable-with={gettext("Saving...")}>
              {gettext("Save batch")}
            </.button>
            <.button
              :if={@action == :edit_batch}
              phx-target={@myself}
              type="button"
              variant="destructive"
              phx-click="delete"
              phx-disable-with={gettext("Deleting...")}
              data-confirm={gettext("Are you sure?")}
            >
              {gettext("Delete batch")}
            </.button>
          </div>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    changeset = Tickets.change_ticket_batch(assigns.batch)

    {:ok,
     assign(socket, form: to_form(changeset))
     |> assign(assigns)}
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
    save_batch(socket, socket.assigns.action, batch_params)
  end

  def handle_event("delete", _, socket) do
    {:ok, _} = Tickets.delete_ticket_batch(socket.assigns.batch)

    {:noreply,
     socket
     |> put_flash(:info, gettext("Batch deleted successfully"))
     |> push_navigate(to: return_path(socket.assigns.event))}
  end

  defp save_batch(socket, :edit_batch, batch_params) do
    case Tickets.update_ticket_batch(
           socket.assigns.current_scope,
           socket.assigns.batch,
           batch_params
         ) do
      {:ok, _batch} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Batch updated successfully"))
         |> push_navigate(to: return_path(socket.assigns.event))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_batch(socket, :new_batch, batch_params) do
    case Tickets.create_ticket_batch(socket.assigns.current_scope, batch_params) do
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

  defp title(:edit_batch), do: gettext("Edit batch")
  defp title(:new_batch), do: gettext("New batch")
end
