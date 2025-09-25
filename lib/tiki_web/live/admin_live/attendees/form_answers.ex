defmodule TikiWeb.AdminLive.Attendees.FormAnswers do
  use TikiWeb, :live_view

  alias Tiki.Localizer

  import TikiWeb.Component.Card
  import TikiWeb.Component.Select

  def render(assigns) do
    ~H"""
    <div class="flex w-full flex-col gap-2 sm:flex-row">
      <div>
        <.card_title class="sm:col-span-6">
          {gettext("Form answers")}
        </.card_title>
        <p class="text-muted-foreground text-sm">
          {gettext(
            "Summary of all form answers, just select the form you are interested in. If you wish to export the data to a csv file, click the export button."
          )}
        </p>
      </div>

      <.link
        href={~p"/admin/events/#{@event}/attendees/form-answers/export"}
        target="_blank"
        class="ml-auto h-fit w-full sm:w-auto"
      >
        <.button variant="outline" class="flex w-full flex-row items-center gap-1 sm:w-auto">
          <.icon name="hero-arrow-down-on-square-stack" class="size-4" />
          {gettext("Export all")}
        </.button>
      </.link>
    </div>

    <div class="mt-4 flex flex-col gap-4 lg:mt-8">
      <div class="bg-muted text-muted-foreground hidden h-10 items-center justify-center rounded-md p-1 lg:inline-flex xl:max-w-2xl">
        <button
          :for={form <- @forms}
          class={[
            "rounded-xs ring-offset-background flex inline-flex w-full flex-row items-center justify-center justify-evenly gap-2 whitespace-nowrap px-3 py-1.5 text-sm font-medium transition-all focus-visible:ring-ring focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50",
            @form.id == form.id && "bg-background text-foreground shadow-xs"
          ]}
          phx-click={JS.push("set_form", value: %{form_id: form.id})}
        >
          {form.name}
        </button>
      </div>

      <div class="flex flex-col gap-2 lg:hidden">
        <p class="text-foreground text-sm font-medium">{gettext("Form")}</p>
        <.form for={%{}} phx-change="set_form" id="form-select-form">
          <.select
            :let={select}
            name="form_id"
            id="form-select"
            class="w-full"
            value={@form.id}
            label={@form.name}
          >
            <.select_trigger builder={select} />
            <.select_content builder={select} class="w-full">
              <.select_group>
                <.select_item :for={form <- @forms} builder={select} value={form.id} label={form.name}>
                  {form.name}
                </.select_item>
              </.select_group>
            </.select_content>
          </.select>
        </.form>
      </div>

      <div :for={question <- @form.questions} :if={@form} class="rounded-lg border p-4 text-sm">
        <span class=" font-semibold">{question.name}</span>
        <div class="mt-2 flex max-h-64 flex-col divide-y overflow-y-auto border-t pt-2">
          <%= if @response_counts[question.id] do %>
            <div
              :for={{answer, count} <- @response_counts[question.id]}
              class="flex flex-row items-center gap-2 py-2 last:pb-0"
            >
              <div class="min-w-6 min-h-6 bg-accent flex items-center justify-center rounded-full font-medium">
                {count}
              </div>
              <span>
                {answer}
              </span>
            </div>
          <% else %>
            <div class="flex flex-row items-center gap-2 pt-2">
              <span class="min-h-6">{gettext("No answers")}</span>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def mount(%{"id" => event_id}, _session, socket) do
    event =
      Tiki.Events.get_event!(event_id)
      |> Localizer.localize()

    with :ok <- Tiki.Policy.authorize(:event_view, socket.assigns.current_user, event) do
      forms =
        Tiki.Forms.list_forms_for_event(event_id)
        |> Localizer.localize()

      {:ok,
       assign(socket, forms: forms, event: event)
       |> assign_breadcrumbs([
         {"Dashboard", ~p"/admin"},
         {"Events", ~p"/admin/events"},
         {event.name, ~p"/admin/events/#{event.id}"},
         {"Form answers", ~p"/admin/events/#{event.id}/attendees/form-answers"}
       ])}
    else
      {:error, :unauthorized} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("You are not authorized to do that."))
         |> redirect(to: ~p"/admin")}
    end
  end

  def handle_params(%{"form" => form_id}, _uri, socket) do
    form =
      Tiki.Forms.list_responses!(form_id)
      |> Localizer.localize()

    if form.event_id != socket.assigns.event.id do
      {:noreply,
       socket
       |> put_flash(:error, gettext("Invalid form for event"))
       |> push_patch(to: ~p"/admin/events/#{socket.assigns.event.id}/attendees/form-answers")}
    else
      response_counts =
        Enum.reject(form.responses, &is_nil/1)
        |> Enum.flat_map(& &1.question_responses)
        |> Enum.group_by(& &1.question_id, &(&1.answer || &1.multi_answer))
        |> Enum.map(fn {key, values} ->
          {key, Enum.frequencies(List.flatten(values)) |> Enum.sort_by(fn {_, c} -> c end, &>=/2)}
        end)
        |> Enum.into(%{})

      {:noreply, assign(socket, form: form, response_counts: response_counts)}
    end
  end

  def handle_params(_params, _uri, socket) do
    form = socket.assigns.forms |> List.first()

    {:noreply,
     push_patch(socket,
       to: ~p"/admin/events/#{socket.assigns.event.id}/attendees/form-answers?form=#{form.id}"
     )}
  end

  def handle_event("set_form", %{"form_id" => form_id}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/admin/events/#{socket.assigns.event.id}/attendees/form-answers?form=#{form_id}"
     )}
  end
end
