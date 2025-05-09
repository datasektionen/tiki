defmodule TikiWeb.AdminLive.Event.FormComponent do
  use TikiWeb, :live_component

  alias Tiki.Events

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>{gettext("Use this form to manage events")}</:subtitle>
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

        <.input
          field={@form[:is_hidden]}
          type="checkbox"
          label={gettext("Hidden event")}
          description={gettext("The event will only be accessable using a direct link")}
        />

        <.input
          :if={@action == :edit}
          field={@form[:default_form_id]}
          type="select"
          label={gettext("Default signup form")}
          options={options_for_forms(@forms)}
          placeholder={gettext("Select a form")}
        />
        <.input field={@form[:max_order_size]} type="number" label={gettext("Max tickets per order")} />

        <.input
          field={@form[:event_date]}
          type="datetime-local"
          label={gettext("Event date")}
          description={gettext("In 'Europe/Stockholm' timezone")}
        />

        <.input field={@form[:location]} type="text" label={gettext("Location")} />

        <.image_upload upload={@uploads.photo} label={gettext("Event cover image")} />

        <:actions>
          <div class="flex flex-row gap-2">
            <.button phx-disable-with={gettext("Saving...")}>{gettext("Save event")}</.button>
            <.button
              :if={@id != "new"}
              variant="destructive"
              navigate={~p"/admin/events/#{@event}/delete"}
            >
              {gettext("Delete event")}
            </.button>
          </div>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{event: event, action: action} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> apply_action(action, event)
     |> allow_upload(
       :photo,
       accept: ~w[.png .jpeg .jpg],
       max_entries: 1,
       auto_upload: true,
       external: &presign_upload/2
     )}
  end

  defp apply_action(socket, :new, event) do
    changeset = Events.change_event(event)

    socket
    |> assign(:forms, [])
    |> assign_form(changeset)
  end

  defp apply_action(socket, existing, event) when existing in [:edit, :delete] do
    changeset = Events.change_event(event)
    forms = Tiki.Forms.list_forms_for_event(event.id)

    socket
    |> assign(:forms, forms)
    |> assign_form(changeset)
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
    event_params =
      Map.put(event_params, "team_id", socket.assigns.current_team.id)
      |> put_image_url(socket)

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

  defp put_image_url(params, socket) do
    {completed, []} = uploaded_entries(socket, :photo)

    case completed do
      [] -> params
      [image | _] -> Map.put(params, "image_url", "uploads/#{image.client_name}")
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp options_for_forms(forms) do
    Enum.map(forms, fn form -> {form.name, form.id} end)
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp presign_upload(entry, socket) do
    form = Tiki.S3.presign_form(entry)

    meta = %{
      uploader: "S3",
      key: "uploads/#{entry.client_name}",
      url: form.url,
      fields: Map.new(form.fields)
    }

    {:ok, meta, socket}
  end
end
