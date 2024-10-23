defmodule TikiWeb.AdminLive.Dashboard.Index do
  use TikiWeb, :live_view

  import TikiWeb.Component.Card

  def mount(_params, _session, socket) do
    events = Tiki.Events.list_events()

    {:ok, assign(socket, events: events)}
  end

  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Dashboard")
    |> assign(:breadcrumbs, [
      {"Dashboard", ~p"/admin"}
    ])
  end

  def render(assigns) do
    ~H"""
    TODO?
    """
  end
end
