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
    socket
    |> assign(:page_title, gettext("Edit event"))
    |> assign_breadcrumbs([
      {"Dashboard", ~p"/admin"},
      {"Events", ~p"/admin/events"},
      {"Edit event", ~p"/admin/events/#{id}/edit"}
    ])
    |> assign(:event, Events.get_event!(id))
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

  def render(assigns) do
    ~H"""
    <div :if={@live_action in [:edit, :new]}>
      <.live_component
        module={TikiWeb.AdminLive.Event.FormComponent}
        id={@event.id || "new"}
        title={@page_title}
        action={@live_action}
        event={@event}
      />
    </div>
    """
  end
end
