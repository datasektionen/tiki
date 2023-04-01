defmodule TikiWeb.AdminLive.Event.BatchFormComponent do
  use TikiWeb, :live_component

  alias Tiki.Tickets

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage batch records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="batch-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Namn" />
        <.input field={@form[:max_size]} type="number" label="Antal biljetter" />
        <.input
          field={@form[:parent_batch_id]}
          type="select"
          label="Parent batch"
          options={options_for_parent_batch(@batches, @batch)}
          prompt="Ingen"
        />

        <:actions>
          <div>
            <.button phx-disable-with="Saving...">Save batch</.button>
            <.button
              :if={@action == :edit_batch}
              type="button"
              phx-click="delete"
              phx-disable-with="Deleting..."
              class="bg-red-700 hover:bg-red-900"
              phx-target={@myself}
              data-confirm="Are you sure?"
            >
              Delete batch
            </.button>
          </div>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{batch: batch} = assigns, socket) do
    changeset = Tickets.change_ticket_batch(batch)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
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

    notify_parent({:deleted, socket.assigns.batch})

    {:noreply,
     socket
     |> put_flash(:info, "Batch deleted successfully")
     |> push_patch(to: socket.assigns.patch)}
  end

  defp save_batch(socket, :edit_batch, batch_params) do
    case Tickets.update_ticket_batch(socket.assigns.batch, batch_params) do
      {:ok, batch} ->
        notify_parent({:saved, batch})

        {:noreply,
         socket
         |> put_flash(:info, "Batch updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_batch(socket, :new_batch, batch_params) do
    batch_params = Map.put(batch_params, "event_id", socket.assigns.batch.event_id)

    case Tickets.create_ticket_batch(batch_params) do
      {:ok, batch} ->
        notify_parent({:saved, batch})

        {:noreply,
         socket
         |> put_flash(:info, "Batch created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp options_for_parent_batch(batches, batch),
    do:
      Enum.map(batches, fn batch -> {batch.name, batch.id} end)
      |> Enum.reject(fn {_, id} -> id == batch.id end)
end
