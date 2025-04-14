defmodule TikiWeb.Layouts do
  use TikiWeb, :html

  import TikiWeb.Component.Sidebar
  import TikiWeb.Component.Sheet
  import TikiWeb.Component.DropdownMenu
  import TikiWeb.Component.Menu

  embed_templates "layouts/*"

  defp show_emb_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.set_attribute({"data-state", "open"}, to: "##{id}")
    |> JS.show(to: "##{id}", transition: {"_", "_", "_"}, time: 150)
    |> JS.focus_first(to: "##{id}-content")
  end
end
