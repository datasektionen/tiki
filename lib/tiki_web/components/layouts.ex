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

  attr :event, :map
  attr :active_tab, :atom, default: nil

  defp sidebar(%{event: event} = assigns) do
    ~H"""
    Event
    """
  end

  defp sidebar(assigns) do
    ~H"""
    <div class="text-white flex flex-col gap-4">
      <.sidebar_item
        icon="home-mini"
        text="Alla event"
        to={~p"/admin"}
        active={@active_tab == :dashboard}
      />
      <.sidebar_item
        icon="cog-6-tooth-mini"
        text="Inställningar"
        to={~p"/admin/settings"}
        active={@active_tab == :settings}
      />
    </div>
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
      <.icon name={"hero-#{@icon}"} class="w-5 h-5" />
      <div class="text-sm font-bold"><%= @text %></div>
    </.link>
    """
  end
end
