defmodule TikiWeb.LiveHelpers do
  use Phoenix.LiveView

  def assign_breadcrumbs(socket, crumbs) do
    # Translate the crumbs
    crumbs =
      Enum.map(crumbs, fn {label, url} -> {Gettext.gettext(TikiWeb.Gettext, label), url} end)

    assign(socket, breadcrumbs: crumbs)
  end

  def time_to_string(time) do
    Tiki.Cldr.DateTime.to_string!(time, format: :yMMMEd)
    |> String.capitalize()
  end
end
