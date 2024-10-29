defmodule TikiWeb.AdminLive.Event.FormComponent do
  use TikiWeb, :live_component

  alias Tiki.Events

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle><%= gettext("Use this form to manage events") %></:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="event-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label={gettext("Name")} />
        <.input field={@form[:description]} type="textarea" label={gettext("Description")} />
        <.input field={@form[:event_date]} type="datetime-local" label={gettext("Event date")} />
        <.input field={@form[:location]} type="text" label={gettext("Location")} />
        <.input field={@form[:image_url]} type="text" label={gettext("Image url")} />
        <:actions>
          <div class="flex flex-row gap-2">
            <.button phx-disable-with={gettext("Saving...")}><%= gettext("Save event") %></.button>
            <.button
              :if={@id != "new"}
              variant="destructive"
              navigate={~p"/admin/events/#{@event}/delete"}
            >
              <%= gettext("Delete event") %>
            </.button>
          </div>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{event: event} = assigns, socket) do
    changeset = Events.change_event(event)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"event" => event_params}, socket) do
    changeset =
      socket.assigns.event
      |> Events.change_event(event_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"event" => event_params}, socket) do
    event_params = Map.put(event_params, "team_id", socket.assigns.current_team.id)
    save_event(socket, socket.assigns.action, event_params)
  end

  defp save_event(socket, :edit, event_params) do
    case Events.update_event(socket.assigns.event, event_params) do
      {:ok, event} ->
        notify_parent({:saved, event})

        {:noreply,
         socket
         |> put_flash(:info, gettext("Event updated successfully"))
         |> push_navigate(to: ~p"/admin/events/#{event}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_event(socket, :new, event_params) do
    case Events.create_event(event_params) do
      {:ok, event} ->
        notify_parent({:saved, event})

        {:noreply,
         socket
         |> put_flash(:info, gettext("Event created successfully"))
         |> push_navigate(to: ~p"/admin/events/#{event}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
