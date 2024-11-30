defmodule TikiWeb.Layouts do
  use TikiWeb, :html

  import TikiWeb.Component.Sidebar
  import TikiWeb.Component.Sheet

  embed_templates "layouts/*"
end
