defmodule TikiWeb.Nav.ActiveTab do
  defmacro __using__(_opts) do
    quote do
      import TikiWeb.Nav.ActiveTab

      @tabs []
      @before_compile TikiWeb.Nav.ActiveTab
    end
  end

  defmacro tab(module, action, tab_val) do
    quote do
      @tabs [{TikiWeb.unquote(module), unquote(action), unquote(tab_val)} | @tabs]
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def active_tab(view, action) do
        Enum.reduce_while(@tabs, nil, fn {mod, act, tab}, found ->
          case view == mod && action == act do
            true -> {:halt, tab}
            false -> {:cont, found}
          end
        end)
      end
    end
  end
end

defmodule TikiWeb.Nav do
  @moduledoc """
  This plug sets the :active_tag, based on the current
  module and live_action.
  """
  use TikiWeb, :html
  use TikiWeb.Nav.ActiveTab

  def on_mount(:default, _params, _session, socket) do
    {:cont, Phoenix.LiveView.attach_hook(socket, :nav_info, :handle_params, &set_nav/3)}
  end

  tab AdminLive.Dashboard.Index, :index, :dashboard
  tab AdminLive.Event.Index, :index, :all_events

  tab AdminLive.Team.Index, :index, :all_teams
  tab AdminLive.Team.Form, :new, :new_team

  tab AdminLive.Event.Edit, :new, :new_event

  tab AdminLive.Event.Status, :index, :live_status

  tab AdminLive.Event.Show, :show, :event_overview

  tab AdminLive.Event.Edit, :edit, :event_edit

  tab AdminLive.Attendees.Index, :index, :event_attendees
  tab AdminLive.Attendees.Show, :show, :event_attendees

  tab AdminLive.Ticket.Index, :index, :event_tickets
  tab AdminLive.Ticket.Index, :new_batch, :event_tickets
  tab AdminLive.Ticket.Index, :edit_batch, :event_tickets
  tab AdminLive.Ticket.Index, :new_ticket_type, :event_tickets
  tab AdminLive.Ticket.Index, :edit_ticket_type, :event_tickets

  defp set_nav(_params, url, socket) do
    active_tab = active_tab(socket.view, socket.assigns.live_action)

    {:cont,
     assign(socket, active_tab: active_tab)
     |> assign_new(:breadcrumbs, fn -> [{Atom.to_string(socket.assigns.live_action), url}] end)}
  end
end
