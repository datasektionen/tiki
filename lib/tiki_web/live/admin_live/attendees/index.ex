defmodule TikiWeb.AdminLive.Attendees.Index do
  use TikiWeb, :live_view

  def mount(%{"id" => event_id}, _session, socket) do
    event = Tiki.Events.get_event!(event_id)

    {:ok, assign(socket, event: event)}
  end

  def render(assigns) do
    ~H"""

    """
  end
end
