defmodule TikiWeb.Layouts do
  use TikiWeb, :html

  import TikiWeb.Component.Sidebar

  embed_templates "layouts/*"
end
