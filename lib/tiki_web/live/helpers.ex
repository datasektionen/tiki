defmodule TikiWeb.LiveHelpers do
  use Phoenix.LiveView

  def assign_breadcrumbs(socket, crumbs) do
    # Translate the crumbs
    crumbs =
      Enum.map(crumbs, fn {label, url} -> {Gettext.gettext(TikiWeb.Gettext, label), url} end)

    assign(socket, breadcrumbs: crumbs)
  end
end
