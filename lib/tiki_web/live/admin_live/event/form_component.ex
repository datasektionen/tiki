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
        <.bilingual_input
          field_en={@form[:name]}
          field_sv={@form[:name_sv]}
          type="text"
          label={gettext("Name")}
          type_context="event title"
          target={@myself}
        />
        <.bilingual_input
          field_en={@form[:description]}
          field_sv={@form[:description_sv]}
          type="textarea"
          label={gettext("Description")}
          type_context="event description"
          target={@myself}
        />

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
        socket.assigns.event
        |> Events.change_event(form_params)
        |> Map.put(:action, :validate)

      {:ok, assign_form(socket, changeset)}
    else
      {:error, reason} ->
        changeset =
          socket.assigns.event
          |> Events.change_event(form_params)
          |> Ecto.Changeset.add_error(
            String.to_atom(to),
            gettext("Failed to generate translation: %{reason}", reason: reason)
          )
          |> Map.put(:action, :validate)

        {:ok, assign_form(socket, changeset)}
    end
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
      socket.assigns.event
      |> Events.change_event(form_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
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
      [image | _] -> Map.put(params, "image_url", "uploads/#{image.uuid}")
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
      key: "uploads/#{entry.uuid}",
      url: form.url,
      fields: Map.new(form.fields)
    }

    {:ok, meta, socket}
  end
end
