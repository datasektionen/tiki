defmodule TikiWeb.Layouts do
  use TikiWeb, :html

  import TikiWeb.Component.Sidebar
  import TikiWeb.Component.Sheet
  import TikiWeb.Component.DropdownMenu
  import TikiWeb.Component.Menu

  embed_templates "layouts/*"
end
