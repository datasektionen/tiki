defmodule TikiWeb.Nav.ActiveTab do
  defmacro __using__(_opts) do
    quote do
      import TikiWeb.Nav.ActiveTab

      @tabs []
      @before_compile TikiWeb.Nav.ActiveTab
    end
  end

  defmacro tab(module, tab_val) do
    quote do
      @tabs [{TikiWeb.unquote(module), unquote(tab_val)} | @tabs]
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def active_tab(view) do
        Enum.reduce_while(@tabs, nil, fn {mod, tab}, found ->
          case view == mod do
            true -> {:halt, tab}
            false -> {:cont, found}
          end
        end)
      end
    end
  end
end

defmodule TikiWeb.Nav do
  use TikiWeb, :html
  use TikiWeb.Nav.ActiveTab

  def on_mount(:default, _params, _session, socket) do
    {:cont,
     socket
     |> Phoenix.LiveView.attach_hook(:active_tab, :handle_params, &set_active_tab/3)}
  end

  tab AdminLive.Dashboard.Index, :dashboard
  tab AdminLive.Event.Show, :event_overview
  tab AdminLive.Event.PurchaseSummary, :live_purchases
  tab AdminLive.Attendees.Index, :attendees

  defp set_active_tab(_params, _url, socket) do
    active_tab = active_tab(socket.view)

    {:cont, assign(socket, active_tab: active_tab)}
  end
end
