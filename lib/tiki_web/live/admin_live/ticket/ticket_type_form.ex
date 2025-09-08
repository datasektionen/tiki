defmodule TikiWeb.AdminLive.Ticket.TicketTypeFormComponent do
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
            "Manage ticket types for your event. Each ticket type needs to be assigned to a batch before they can be created."
          )}
        </:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="ticket_type-form"
        phx-change="validate"
        phx-submit="save"
        phx-target={@myself}
      >
        <.bilingual_input
          field_en={@form[:name]}
          field_sv={@form[:name_sv]}
          type="text"
          label={gettext("Name")}
          type_context="ticket name"
          target={@myself}
        />

        <.bilingual_input
          field_en={@form[:description]}
          field_sv={@form[:description_sv]}
          type="textarea"
          label={gettext("Description")}
          type_context="ticket description"
          target={@myself}
        />
        <.input
          field={@form[:start_time]}
          type="datetime-local"
          label={gettext("Start time")}
          description={gettext("In 'Europe/Stockholm' timezone")}
        />
        <.input
          field={@form[:end_time]}
          type="datetime-local"
          label={gettext("End time")}
          description={gettext("In 'Europe/Stockholm' timezone")}
        />

        <.input
          :if={@event.default_form_id != nil}
          field={@form[:form_id]}
          type="select"
          label={gettext("Signup form")}
          options={options_for_forms(@forms)}
          default={@event.default_form_id}
        />

        <.input
          :if={@event.default_form_id == nil}
          field={@form[:form_id]}
          type="select"
          label={gettext("Signup form")}
          options={options_for_forms(@forms)}
          prompt={gettext("Select a form")}
        />

        <.input field={@form[:purchasable]} type="checkbox" label={gettext("Purchasable")} />
        <.input
          field={@form[:purchase_limit]}
          type="text"
          label={gettext("Max number of tickets per order")}
          description={gettext("Leave blank for unlimited")}
        />

        <.input field={@form[:price]} type="number" label={gettext("Price")} />
        <.input
          field={@form[:release_time]}
          type="datetime-local"
          label={gettext("Release time")}
          description={
            gettext("In 'Europe/Stockholm' timezone. Leave blank to make immediately available")
          }
        />

        <.input
          field={@form[:expire_time]}
          type="datetime-local"
          label={gettext("Purchase deadline")}
          description={gettext("In 'Europe/Stockholm' timezone. Leave blank for none")}
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
              {gettext("Save ticket type")}
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
              {gettext("Delete ticket type")}
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
    forms = Tiki.Forms.list_forms_for_event(assigns.event.id)

    {:ok,
     assign(socket, assigns)
     |> assign(:forms, forms)
     |> assign(form: to_form(changeset))}
  end

  @impl true
  def update(%{translate_result: result, from: from, to: to}, socket) do
    source_text = socket.assigns.form[String.to_atom(from)].value
    target_text = socket.assigns.form[String.to_atom(to)].value

    form_params =
      socket.assigns.form.source.params
      |> Map.put_new(from, source_text)
      |> Map.put_new(to, target_text)
      |> Map.delete("_unused_#{to}")

    with {:ok, translation} <- result do
      form_params = Map.put(form_params, to, translation)

      changeset =
        socket.assigns.ticket_type
        |> Tickets.change_ticket_type(form_params)
        |> Map.put(:action, :validate)

      {:ok, assign_form(socket, changeset)}
    else
      {:error, reason} ->
        changeset =
          socket.assigns.ticket_type
          |> Tickets.change_ticket_type(form_params)
          |> Ecto.Changeset.add_error(
            String.to_atom(to),
            gettext("Failed to generate translation: %{reason}", reason: reason)
          )
          |> Map.put(:action, :validate)

        {:ok, assign_form(socket, changeset)}
    end
  end

  def handle_event(
        "generate_translation",
        %{"from_field" => from, "to_field" => to, "to_lang" => to_lang, "type_context" => type},
        socket
      ) do
    source_text = socket.assigns.form[String.to_atom(from)].value

    Task.async(fn ->
      {Tiki.Translations.generate_translation(source_text, to_lang, type), from, to}
    end)

    form_params =
      socket.assigns.form.source.params
      |> Map.put(to, gettext("Generating translation..."))

    changeset =
      socket.assigns.ticket_type
      |> Tickets.change_ticket_type(form_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
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
