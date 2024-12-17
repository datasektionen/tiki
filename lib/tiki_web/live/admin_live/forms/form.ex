defmodule TikiWeb.AdminLive.Forms.Form do
  use TikiWeb, :live_view

  alias Tiki.Forms

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.simple_form for={@client_form} id="form-form" phx-change="validate" phx-submit="save">
      <.input field={@client_form[:event_id]} type="hidden" value={@event.id} />

      <.input field={@client_form[:name]} type="text" label={gettext("Name")} />
      <.input field={@client_form[:description]} type="text" label={gettext("Description")} />

      <.label>{gettext("Questions")}</.label>
      <.inputs_for :let={f_nested} field={@client_form[:questions]}>
        <div class="rounded-md border px-4 py-6">
          <input type="hidden" name="form[questions_sort][]" value={f_nested.index} />
          <div class="grid grid-cols-6 gap-2">
            <.input
              field={f_nested[:name]}
              type="text"
              label={gettext("Question")}
              class="col-span-4"
            />
            <.input
              class="col-span-2"
              field={f_nested[:type]}
              type="select"
              label={gettext("Question Type")}
              options={[
                {gettext("Text"), :text},
                {gettext("Long text"), :text_area},
                {gettext("Select"), :select},
                {gettext("Multiple select"), :multi_select}
              ]}
            />
            <.input
              field={f_nested[:description]}
              type="text"
              label={gettext("Description")}
              class="col-span-6"
            />
            <div :if={select?(f_nested[:type])} class="col-span-6">
              <.label>{gettext("Options")}</.label>
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
    event = Tiki.Events.get_event!(event_id)

    {:ok,
     socket
     |> assign(:event, event)
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"form_id" => form_id}) do
    form = Forms.get_form!(form_id)
    changeset = Forms.change_form(form)
    %{event: event} = socket.assigns

    assign(socket, form: form, client_form: to_form(changeset))
    |> assign_breadcrumbs([
      {"Dashboard", ~p"/admin"},
      {"Events", ~p"/admin/events"},
      {event.name, ~p"/admin/events/#{event}"},
      {"Forms", ~p"/admin/events/#{event}/forms"},
      {form.name, ~p"/admin/events/#{event}/forms/#{form.id}/edit"}
    ])
  end

  defp apply_action(socket, :new, _) do
    form = %Forms.Form{}
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

  defp save_form(socket, :new, form_params) do
    case Forms.create_form(form_params) do
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
        {:noreply, assign_form(socket, changeset)}
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

    question =
      case sort do
        ["new" | _] -> Map.update!(question, "options", fn o -> o ++ [nil] end)
        _ -> question
      end

    {index, question}
  end

  defp return_path(form), do: ~p"/admin/events/#{form.event_id}/forms"
end
