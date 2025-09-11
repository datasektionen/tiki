defmodule TikiWeb.AdminLive.Releases.FormComponent do
  use TikiWeb, :live_component

  alias Tiki.Releases

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>{gettext("Use this form to manage ticket releases")}</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="release-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.bilingual_input
          field_en={@form[:name]}
          field_sv={@form[:name_sv]}
          type="text"
          label={gettext("Name")}
          type_context="ticket release name"
          target={@myself}
        />

        <.input
          field={@form[:starts_at]}
          type="datetime-local"
          label={gettext("Open time")}
          description={"#{gettext("Time when release signup opens.")} #{gettext("In 'Europe/Stockholm' timezone")}."}
        />
        <.input
          field={@form[:ends_at]}
          type="datetime-local"
          label={gettext("End time")}
          description={"#{gettext("Time when release signup ends. After this, tickets are sold as usual with no releases.")} #{gettext("In 'Europe/Stockholm' timezone")}."}
        />

        <.input
          field={@form[:ticket_batch_id]}
          type="select"
          label={gettext("Ticket batch")}
          options={options_for_batch(@event.ticket_batches)}
        />

        <:actions>
          <div class="flex flex-row gap-2">
            <.button phx-disable-with={gettext("Saving...")}>{gettext("Save release")}</.button>
            <.button
              :if={@action == :edit}
              variant="destructive"
              navigate={~p"/admin/events/#{@release.event_id}/releases/#{@release}/delete"}
            >
              {gettext("Delete release")}
            </.button>
          </div>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{release: release, action: action} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> apply_action(action, release)}
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
        socket.assigns.release
        |> Releases.change_release(form_params)
        |> Map.put(:action, :validate)

      {:ok, assign_form(socket, changeset)}
    else
      {:error, reason} ->
        changeset =
          socket.assigns.release
          |> Releases.change_release(form_params)
          |> Ecto.Changeset.add_error(
            String.to_atom(to),
            gettext("Failed to generate translation: %{reason}", reason: reason)
          )
          |> Map.put(:action, :validate)

        {:ok, assign_form(socket, changeset)}
    end
  end

  defp apply_action(socket, :new, release) do
    changeset = Releases.change_release(release)

    socket
    |> assign(title: gettext("New release"))
    |> assign_form(changeset)
  end

  defp apply_action(socket, existing, release) when existing in [:edit, :delete] do
    changeset = Releases.change_release(release)

    socket
    |> assign(title: gettext("Edit release"))
    |> assign_form(changeset)
  end

  @impl true
  def handle_event("validate", %{"release" => release_params}, socket) do
    changeset =
      socket.assigns.release
      |> Releases.change_release(release_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"release" => release_params}, socket) do
    save_release(socket, socket.assigns.action, release_params)
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
      socket.assigns.release
      |> Releases.change_release(form_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  defp save_release(socket, :edit, release_params) do
    case Releases.update_release(socket.assigns.release, release_params) do
      {:ok, release} ->
        notify_parent({:saved, release})

        {:noreply,
         socket
         |> put_flash(:info, gettext("Release updated successfully"))
         |> push_navigate(to: ~p"/admin/events/#{socket.assigns.event}/releases")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_release(socket, :new, release_params) do
    release_params = Map.put(release_params, "event_id", socket.assigns.event.id)

    case Releases.create_release(release_params) do
      {:ok, release} ->
        notify_parent({:saved, release})

        {:noreply,
         socket
         |> put_flash(:info, gettext("Release created successfully"))
         |> push_navigate(to: ~p"/admin/events/#{socket.assigns.event}/releases")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp options_for_batch(batches),
    do: Enum.map(batches, fn batch -> {batch.name, batch.id} end)

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
