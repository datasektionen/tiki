defmodule TikiWeb.AdminLive.Event.Edit do
  use TikiWeb, :live_view

  alias Tiki.Events
  alias Tiki.Events.Event

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    event = Events.get_event!(id)

    socket
    |> assign(:page_title, gettext("Edit event"))
    |> assign_breadcrumbs([
      {"Dashboard", ~p"/admin"},
      {"Events", ~p"/admin/events"},
      {event.name, ~p"/admin/events/#{id}"},
      {"Edit event", ~p"/admin/events/#{id}/edit"}
    ])
    |> assign(:event, event)
  end

  defp apply_action(socket, :delete, map) do
    socket
    |> assign(:page_title, gettext("Delete event"))
    |> apply_action(:edit, map)
    |> assign(:delete_form, to_form(%{"confirm" => ""}))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, gettext("New event"))
    |> assign_breadcrumbs([
      {"Dashboard", ~p"/admin"},
      {"Events", ~p"/admin/events"},
      {"New event", ~p"/admin/events/new"}
    ])
    |> assign(:event, %Event{})
  end

  def handle_event("validate_delete", params, socket) do
    {:noreply, assign(socket, :delete_form, to_form(params))}
  end

  def handle_event("save_delete", params, socket) do
    case Events.delete_event(socket.assigns.event) do
      {:ok, _event} ->
        {:noreply,
         put_flash(socket, :info, gettext("Deleted event"))
         |> push_navigate(to: ~p"/admin/events")}

      {:error, _event} ->
        {:noreply,
         put_flash(socket, :error, gettext("Something went wrong"))
         |> assign(:delete_form, to_form(params))}
    end
  end

  def render(assigns) do
    ~H"""
    <div :if={@live_action in [:edit, :new, :delete]}>
      <.live_component
        module={TikiWeb.AdminLive.Event.FormComponent}
        id={@event.id || "new"}
        title={@page_title}
        action={@live_action}
        event={@event}
        current_team={@current_team}
      />
    </div>

    <.dialog
      :if={@live_action == :delete}
      id="delete-dialog"
      show={true}
      on_cancel={JS.navigate(~p"/admin/events/#{@event}/edit")}
    >
      <.dialog_header>
        <.dialog_title>
          {gettext("Delete event?")}
        </.dialog_title>
        <.dialog_description>
          {gettext("This will permanently delete the event")}
        </.dialog_description>

        <.form :let={f} for={@delete_form} phx-change="validate_delete" phx-submit="save_delete">
          <div class="bg-bg-background mt-2 space-y-4">
            <label for={f[:confirm].id} class="text-sm">
              <span>{gettext("Type the full name of the event")}</span>:
              <span class="bg-accent text-accent-foreground rounded-xs px-1 py-0.5">
                {@event.name}
              </span>
            </label>
            <.input field={f[:confirm]} />
            <.button variant="destructive" type="submit" disabled={f[:confirm].value != @event.name}>
              {gettext("Delete event")}
            </.button>
          </div>
        </.form>
      </.dialog_header>
    </.dialog>
    """
  end
end
