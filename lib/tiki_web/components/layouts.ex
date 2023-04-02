defmodule TikiWeb.Layouts do
  use TikiWeb, :html

  embed_templates "layouts/*"

  def show_mobile_sidebar(js \\ %JS{}) do
    js
    |> JS.show(
      to: "#mobile-sidebar-container",
      transition: {"transition fade-in duration-300", "opacity-0", "opacity-100"},
      time: 300
    )
    |> JS.show(
      to: "#mobile-sidebar",
      display: "flex",
      time: 300,
      transition:
        {"transition ease-in-out duration-300 transform", "-translate-x-full", "translate-x-0"}
    )
    |> JS.dispatch("js:exec", to: "#hide-mobile-sidebar", detail: %{call: "focus", args: []})
  end

  def hide_mobile_sidebar(js \\ %JS{}) do
    js
    |> JS.hide(to: "#mobile-sidebar-container", transition: "fade-out")
    |> JS.hide(
      to: "#mobile-sidebar",
      time: 300,
      transition:
        {"transition ease-in-out duration-300 transform", "translate-x-0", "-translate-x-full"}
    )
    |> JS.dispatch("js:exec", to: "#show-mobile-sidebar", detail: %{call: "focus", args: []})
  end

  attr :event, :map, default: nil
  attr :active_tab, :atom, default: nil

  defp sidebar(%{event: nil} = assigns) do
    ~H"""
    <div class="text-white flex flex-col gap-4">
      <.sidebar_item
        icon="hero-home-mini"
        text="Alla event"
        to={~p"/admin"}
        active={@active_tab == :dashboard}
      />
      <.sidebar_item
        icon="hero-cog-6-tooth-mini"
        text="Inställningar"
        to={~p"/admin/settings"}
        active={@active_tab == :settings}
      />
    </div>
    """
  end

  defp sidebar(assigns) do
    ~H"""
    <nav class="flex flex-col justify-between h-full flex-grow">
      <div class="text-white flex flex-col gap-4">
        <.sidebar_item
          icon="hero-home-mini"
          text="Översikt"
          to={~p"/admin/events/#{@event}"}
          active={@active_tab == :event_overview}
        />
        <.sidebar_item
          icon="hero-user-group-mini"
          text="Besökare"
          to={~p"/admin/events/#{@event}/attendees"}
          active={@active_tab == :attendees}
        />
        <.sidebar_item
          icon="hero-ticket-mini"
          text="Biljetter"
          to={~p"/admin/events/#{@event}/tickets"}
          active={@active_tab == :tickets}
        />
        <.sidebar_item
          icon="hero-presentation-chart-line-mini"
          text="Live-status"
          to={~p"/admin/events/#{@event}/purchase-summary"}
          active={@active_tab == :live_purchases}
        />
        <.sidebar_item
          icon="hero-document-text-mini"
          text="Formulär"
          to={~p"/admin/events/#{@event}/forms"}
          active={@active_tab == :forms}
        />
      </div>
      <.sidebar_item
        icon="hero-home-mini"
        text="Alla event"
        to={~p"/admin"}
        active={@active_tab == :dashboard}
      />
    </nav>
    """
  end

  attr :active, :boolean, default: false
  attr :icon, :string
  attr :to, :any
  attr :text, :string

  defp sidebar_item(assigns) do
    ~H"""
    <.link
      navigate={@to}
      class={[
        "border-l-4 pl-4 inline-flex items-center gap-2 py-1 hover:border-white hover:text-white",
        if(@active, do: "border-white", else: "border-gray-900 text-gray-400")
      ]}
    >
      <.icon name={@icon} class="w-5 h-5" />
      <div class="text-sm font-bold"><%= @text %></div>
    </.link>
    """
  end

  attr :class, :string, default: ""

  defp tiki_logo(assigns) do
    ~H"""
    <svg
      class={@class}
      xmlns="http://www.w3.org/2000/svg"
      width="314.896"
      height="305.649"
      viewBox="0 0 83.316 80.87"
    >
      <path
        d="M18.242 61.32c-1.763.008-3.509.38-5.191 1.428-3.365 2.098-4.606 6.204-4.668 11.24-.07 5.675 1.377 10.145 4.65 12.787 3.273 2.642 7.355 2.91 11.276 2.594 7.84-.63 16.697-3.639 23.884-3.652 7.218-.013 16.568 2.872 24.725 3.527 4.078.328 8.166.175 11.62-2.224 3.452-2.4 5.187-6.871 5.089-12.332-.096-5.322-1.509-9.577-4.957-11.768-3.449-2.191-7.273-1.718-11.016-.94-7.485 1.558-16.334 5.14-25.511 5.168-9.183.029-17.566-3.444-24.596-5.072-1.758-.407-3.541-.764-5.305-.756zm60.62 7.793c.884.018 1.443.153 1.679.303.472.3 1.314 1.259 1.389 5.41.072 4.012-.77 5.166-1.785 5.871-1.016.706-3.288 1.14-6.612.873-6.647-.534-16.262-3.567-25.353-3.55-9.121.016-18.367 3.185-24.489 3.677-3.06.247-4.925-.188-5.822-.912-.897-.724-1.843-2.283-1.789-6.703.048-3.917.82-4.66 1.045-4.8.226-.141 1.778-.379 4.684.294 5.81 1.346 15.279 5.306 26.359 5.272 11.086-.035 20.878-4.046 27.053-5.33 1.543-.322 2.755-.422 3.64-.405z"
        style="stroke-linejoin:bevel;-inkscape-stroke:none;paint-order:stroke fill markers"
        transform="translate(-7.272 -8.605)"
      />
      <g style="display:inline">
        <path
          d="M39.994 30.281c-2.585-.001-5.31.085-8.183.24v7.515c19.37-1.093 28.905.691 39.234 9.343l2.402 2.012 2.408-2.004c9.601-7.992 23.217-10.24 39.272-9.342v-7.517c-15.707-.827-30.291 1.202-41.625 9.323-8.219-6.132-17.016-8.893-28.59-9.454a102.776 102.776 0 0 0-4.918-.116zm71.056 9.839a74.37 74.37 0 0 0-2.902.033c-11.923.367-23.85 3.866-34.763 12.503-6.83-5.471-13.413-9.04-21.024-10.723-6.04-1.335-12.615-1.596-20.55-1.193v8.005c7.696-.401 13.695-.15 18.828.985 5.972 1.32 10.967 3.777 16.628 8.159a41.062 41.062 0 0 0-1.924 2.042c-8.032-6.072-15.518-8.248-24.556-8.501-2.816-.079-5.796.037-8.976.271v8.002c12.747-1.044 19.165-.613 28.017 6.035-1.801 1.723-3.726 3.353-5.758 4.637-3.344 2.113-6.809 3.308-10.88 2.877-3.202-.34-6.964-1.74-11.379-5.053v9.5c3.633 2.005 7.15 3.133 10.537 3.492 6.164.654 11.61-1.299 15.988-4.066s7.852-6.332 10.648-9.316c1.855-1.98 2.688-2.702 3.739-3.69 1.036 1.02 1.86 1.77 3.671 3.78 2.732 3.03 6.14 6.643 10.514 9.433s9.875 4.724 16.149 4.033c3.83-.422 7.85-1.788 12.07-4.26v-9.61c-5.12 3.905-9.396 5.544-12.944 5.935-4.227.465-7.686-.726-10.982-2.829-1.754-1.118-3.413-2.51-4.977-3.999 10.871-7.254 19.09-8.608 28.903-7.883v-7.927a70.657 70.657 0 0 0-2.12-.083c-10.437-.232-20.638 1.984-32.296 9.99a62.526 62.526 0 0 0-2.005-2.274c11.386-8.88 23.736-11.142 36.421-10.233V40.26a80.55 80.55 0 0 0-4.077-.14z"
          style="-inkscape-stroke:none;paint-order:stroke fill markers"
          transform="translate(-31.811 -30.281)"
        />
      </g>
    </svg>
    """
  end
end
