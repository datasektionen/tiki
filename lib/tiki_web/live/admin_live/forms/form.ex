defmodule TikiWeb.AdminLive.Forms.Form do
  use TikiWeb, :live_view

  alias Tiki.Forms
  alias Tiki.Localizer

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.simple_form for={@client_form} id="form-form" phx-change="validate" phx-submit="save">
      <.input field={@client_form[:name]} type="text" label={gettext("Name")} />
      <.bilingual_input
        field_en={@client_form[:description]}
        field_sv={@client_form[:description_sv]}
        type="text"
        label={gettext("Description")}
        type_context="form description"
      />

      <.label>{gettext("Questions")}</.label>
      <.inputs_for :let={f_nested} field={@client_form[:questions]}>
        <div class="rounded-md border px-4 py-6">
          <input type="hidden" name="form[questions_sort][]" value={f_nested.index} />
          <div class="grid grid-cols-6 gap-2">
            <.bilingual_input
              field_en={f_nested[:name]}
              field_sv={f_nested[:name_sv]}
              index={f_nested.index}
              type="text"
              label={gettext("Question")}
              type_context="form question"
              class="col-span-4"
            />
            <.input
              class="col-span-3"
              field={f_nested[:type]}
              type="select"
              label={gettext("Question Type")}
              options={[
                {gettext("Text"), :text},
                {gettext("Long text"), :text_area},
                {gettext("Select"), :select},
                {gettext("Multiple select"), :multi_select},
                {gettext("Email"), :email},
                {gettext("Attendee Name"), :attendee_name}
              ]}
            />

            <.bilingual_input
              field_en={f_nested[:description]}
              field_sv={f_nested[:description_sv]}
              type="text"
              index={f_nested.index}
              label={gettext("Description")}
              type_context="form question description"
              class="col-span-6"
            />

            <div :if={select?(f_nested[:type])} class="col-span-6">
              <.label>{gettext("%{label} (English)", label: gettext("Options"))}</.label>
              <div :for={option <- f_nested[:options].value || []} class="flex flex-row items-center">
                <.input
                  class="w-full"
                  type="text"
                  name={"form[questions][#{f_nested.index}][options][]"}
                  value={option}
                />
                <button
                  class="mt-2 ml-2"
                  name={"form[questions][#{f_nested.index}][options_drop][]"}
                  value={option}
                  phx-click={JS.dispatch("change")}
                  type="button"
                >
                  <.icon name="hero-x-mark" class="h-6 w-6" />
                </button>
              </div>

              <button
                name={"form[questions][#{f_nested.index}][options_sort][]"}
                value="new"
                phx-click={JS.dispatch("change")}
                type="button"
                class="text-muted-foreground mt-3 flex flex-row items-center gap-2 text-sm"
              >
                <.icon name="hero-plus-circle" class="h-5 w-5" />{gettext("New option")}
              </button>

              <div :if={f_nested[:options].errors != []}>
                <.error :for={error <- f_nested[:options].errors}>{translate_error(error)}</.error>
              </div>
            </div>

            <div :if={select?(f_nested[:type])} class="col-span-6">
              <.label>{gettext("%{label} (Swedish)", label: gettext("Options"))}</.label>
              <div
                :for={option <- f_nested[:options_sv].value || []}
                class="flex flex-row items-center"
              >
                <.input
                  class="w-full"
                  type="text"
                  name={"form[questions][#{f_nested.index}][options_sv][]"}
                  value={option}
                />
                <button
                  class="mt-2 ml-2"
                  name={"form[questions][#{f_nested.index}][options_sv_drop][]"}
                  value={option}
                  phx-click={JS.dispatch("change")}
                  type="button"
                >
                  <.icon name="hero-x-mark" class="h-6 w-6" />
                </button>
              </div>
              <button
                name={"form[questions][#{f_nested.index}][options_sv_sort][]"}
                value="new"
                phx-click={JS.dispatch("change")}
                type="button"
                class="text-muted-foreground mt-3 flex flex-row items-center gap-2 text-sm"
              >
                <.icon name="hero-plus-circle" class="h-5 w-5" />{gettext("New option")}
              </button>

              <div :if={f_nested[:options_sv].errors != []}>
                <.error :for={error <- f_nested[:options_sv].errors}>{translate_error(error)}</.error>
              </div>
            </div>

            <div class="col-span-6 mt-2 flex flex-row items-center justify-end divide-x divide-solid">
              <.input
                field={f_nested[:required]}
                type="checkbox"
                label={gettext("Required")}
                class="px-2"
              />
              <button
                name="form[questions_drop][]"
                value={f_nested.index}
                phx-click={JS.dispatch("change")}
                type="button"
                class="px-2"
              >
                <.icon name="hero-trash" class="text-foreground h-5 w-5" />
              </button>
            </div>
          </div>
        </div>
      </.inputs_for>

      <button
        type="button"
        class="text-muted-foreground flex flex-row items-center gap-2 text-sm"
        name="form[questions_sort][]"
        value="new"
        phx-click={JS.dispatch("change")}
      >
        <.icon name="hero-plus-circle" class="h-5 w-5" /> {gettext("New question")}
      </button>

      <:actions>
        <.button phx-disable-with={gettext("Saving...")}>
          {gettext("Save form")}
        </.button>
      </:actions>
    </.simple_form>
    """
  end

  @impl Phoenix.LiveView
  def mount(%{"id" => event_id} = params, _session, socket) do
    event =
      Tiki.Events.get_event!(event_id)
      |> Localizer.localize()

    with :ok <- Tiki.Policy.authorize(:event_manage, socket.assigns.current_user, event) do
      {:ok,
       socket
       |> assign(:event, event)
       |> apply_action(socket.assigns.live_action, params)}
    else
      {:error, :unauthorized} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("You are not authorized to do that."))
         |> redirect(to: ~p"/admin/events/#{event}/forms")}
    end
  end

  defp apply_action(socket, :edit, %{"form_id" => form_id}) do
    form = Forms.get_form!(form_id)
    changeset = Forms.change_form(form)
    %{event: event} = socket.assigns

    if event.id == form.event_id do
      assign(socket, form: form, client_form: to_form(changeset))
      |> assign_breadcrumbs([
        {"Dashboard", ~p"/admin"},
        {"Events", ~p"/admin/events"},
        {event.name, ~p"/admin/events/#{event}"},
        {"Forms", ~p"/admin/events/#{event}/forms"},
        {form.name, ~p"/admin/events/#{event}/forms/#{form.id}/edit"}
      ])
    else
      socket
      |> put_flash(:error, gettext("You are not authorized to do that."))
      |> redirect(to: ~p"/admin")
    end
  end

  defp apply_action(socket, :new, _) do
    form = %Forms.Form{
      questions: [
        %Tiki.Forms.Question{name: gettext("Name"), required: true, type: :attendee_name},
        %Tiki.Forms.Question{name: gettext("Email"), required: true, type: :email}
      ]
    }

    changeset = Forms.change_form(form)
    %{event: event} = socket.assigns

    assign(socket, form: form, client_form: to_form(changeset))
    |> assign_breadcrumbs([
      {"Dashboard", ~p"/admin"},
      {"Events", ~p"/admin/events"},
      {event.name, ~p"/admin/events/#{event}"},
      {"Forms", ~p"/admin/events/#{event}/forms"},
      {"New", ~p"/admin/events/#{event}/forms/new"}
    ])
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"form" => params}, socket) do
    params = merge_options(params)

    changeset =
      Forms.change_form(socket.assigns.form, params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"form" => params}, socket) do
    save_form(socket, socket.assigns.live_action, params)
  end

  def handle_event(
        "generate_translation",
        %{
          "from_field" => from,
          "to_field" => to,
          "to_lang" => to_lang,
          "type_context" => type,
          "index" => index
        },
        socket
      ) do
    form_params = prepare_form_params(socket, from, to, index)
    source_text = get_source_text(form_params, from, index)

    Task.async(fn ->
      {Tiki.Translations.generate_translation(source_text, to_lang, type), from, to, index}
    end)

    form_params =
      case index do
        nil ->
          Map.put(form_params, to, gettext("Generating translation..."))

        number ->
          Map.update!(form_params, "questions", fn questions ->
            Map.update!(questions, "#{number}", fn question ->
              Map.put(question, to, gettext("Generating translation..."))
            end)
          end)
      end

    changeset =
      socket.assigns.form
      |> Forms.change_form(form_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_info({ref, {result, from, to, index}}, socket) do
    Process.demonitor(ref, [:flush])

    form_params = prepare_form_params(socket, from, to, index)

    with {:ok, translation} <- result do
      form_params =
        case index do
          nil ->
            Map.put(form_params, to, translation)

          number ->
            Map.update!(form_params, "questions", fn questions ->
              Map.update!(questions, "#{number}", fn question ->
                Map.put(question, to, translation)
              end)
            end)
        end

      changeset =
        socket.assigns.form
        |> Forms.change_form(form_params)
        |> Map.put(:action, :validate)

      {:noreply, assign_form(socket, changeset)}
    else
      {:error, reason} ->
        changeset =
          case index do
            nil ->
              socket.assigns.form
              |> Forms.change_form(form_params)
              |> Ecto.Changeset.add_error(
                String.to_atom(to),
                gettext("Failed to generate translation: %{reason}", reason: reason)
              )
              |> Map.put(:action, :validate)

            number when is_integer(number) ->
              changeset =
                socket.assigns.form
                |> Forms.change_form(form_params)

              update_in(changeset.changes.questions, fn changesets ->
                Enum.with_index(changesets)
                |> Enum.map(fn {changeset, index} ->
                  if index == number do
                    Ecto.Changeset.add_error(
                      changeset,
                      String.to_atom(to),
                      gettext("Failed to generate translation: %{reason}", reason: reason)
                    )
                  else
                    changeset
                  end
                end)
              end)
              |> Map.put(:action, :validate)
          end

        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp prepare_form_params(socket, from, to, index) do
    case index do
      nil ->
        source_text = socket.assigns.client_form[String.to_atom(from)].value
        target_text = socket.assigns.client_form[String.to_atom(to)].value

        socket.assigns.client_form.source.params
        |> Map.put_new(from, source_text)
        |> Map.put_new(to, target_text)
        |> Map.put_new_lazy(
          "questions",
          fn ->
            Enum.map(socket.assigns.client_form[:questions].value, fn question ->
              %{
                "description" => question.description,
                "description_sv" => question.description_sv,
                "id" => question.id,
                "name" => question.name,
                "name_sv" => question.name_sv,
                "options" => question.options,
                "options_sv" => question.options_sv,
                "required" => question.required,
                "type" => question.type
              }
            end)
            |> Enum.with_index(fn el, index -> {"#{index}", el} end)
            |> Map.new()
          end
        )
        |> Map.delete("_unused_#{to}")

      number when is_integer(number) ->
        socket.assigns.client_form.source.params
        |> Map.put_new_lazy(
          "questions",
          fn ->
            Enum.map(socket.assigns.client_form[:questions].value, fn question ->
              %{
                "description" => question.description,
                "description_sv" => question.description_sv,
                "id" => question.id,
                "name" => question.name,
                "name_sv" => question.name_sv,
                "options" => question.options,
                "options_sv" => question.options_sv,
                "required" => question.required,
                "type" => question.type
              }
            end)
            |> Enum.with_index(fn el, index -> {"#{index}", el} end)
            |> Map.new()
          end
        )
        |> Map.update!("questions", fn questions ->
          Map.update!(questions, "#{number}", fn question ->
            Map.delete(question, "_unused_#{to}")
          end)
        end)
    end
  end

  defp get_source_text(params, from, index) do
    case index do
      nil ->
        Map.get(params, from)

      number when is_integer(number) ->
        questions = Map.get(params, "questions")
        Map.get(questions, "#{number}") |> Map.get(from)
    end
  end

  defp save_form(socket, :new, form_params) do
    case Forms.create_form(socket.assigns.event.id, form_params) do
      {:ok, form} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Form created successfully"))
         |> push_navigate(to: return_path(form))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_form(socket, :edit, form_params) do
    case Forms.update_form(socket.assigns.form, merge_options(form_params)) do
      {:ok, form} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Form updated successfully"))
         |> push_navigate(to: return_path(form))}

      {:error, %Ecto.Changeset{} = changeset} ->
        socket = assign_form(socket, changeset)
        {:noreply, socket}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset)
    assign(socket, :client_form, form)
  end

  defp select?(form_field) do
    form_field.value == "select" || form_field.value == "multi_select" ||
      form_field.value == :select || form_field.value == :multi_select
  end

  defp merge_options(form_params) do
    Map.update(
      form_params,
      "questions",
      %{},
      fn qs ->
        Enum.map(qs, &replace_options/1)
        |> Enum.into(%{})
      end
    )
  end

  defp replace_options({index, question}) do
    drop = question["options_drop"] || []
    sort = question["options_sort"] || []

    drop_sv = question["options_sv_drop"] || []
    sort_sv = question["options_sv_sort"] || []

    question =
      Map.update(
        question,
        "options",
        [],
        fn options ->
          options
          |> Enum.reject(fn option -> option in drop end)
          |> Enum.map(fn option ->
            if option == "" do
              nil
            else
              option
            end
          end)
        end
      )
      |> Map.update("options_sv", [], fn options ->
        options
        |> Enum.reject(fn option -> option in drop_sv end)
        |> Enum.map(fn option ->
          if option == "" do
            nil
          else
            option
          end
        end)
      end)

    question =
      case sort do
        ["new" | _] -> Map.update!(question, "options", fn o -> o ++ [nil] end)
        _ -> question
      end

    question =
      case sort_sv do
        ["new" | _] -> Map.update!(question, "options_sv", fn o -> o ++ [nil] end)
        _ -> question
      end

    {index, question}
  end

  defp return_path(form), do: ~p"/admin/events/#{form.event_id}/forms"
end
