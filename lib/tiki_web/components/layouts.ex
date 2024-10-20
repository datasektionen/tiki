defmodule TikiWeb.Layouts do
  use TikiWeb, :html

  import TikiWeb.Component.Table
  import TikiWeb.Component.Label
  import TikiWeb.Component.Tooltip
  import TikiWeb.Component.Button
  import TikiWeb.Component.Breadcrumb
  import TikiWeb.Component.Menu
  import TikiWeb.Component.Tabs
  import TikiWeb.Component.Sheet
  import TikiWeb.Component.DropdownMenu
  import TikiWeb.Component.Card
  import TikiWeb.Component.Badge
  import TikiWeb.Component.Skeleton
  import TikiWeb.Component.Sidebar

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
end
