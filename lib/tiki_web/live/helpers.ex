defmodule TikiWeb.LiveHelpers do
  use Phoenix.LiveView

  def assign_breadcrumbs(socket, crumbs) do
    # Translate the crumbs
    crumbs =
      Enum.map(crumbs, fn {label, url} -> {Gettext.gettext(TikiWeb.Gettext, label), url} end)

    assign(socket, breadcrumbs: crumbs)
  end

  def time_to_string(time, opts \\ []) do
    format = Keyword.get(opts, :format, :yMMMEd)
    timezone = Keyword.get(opts, :timezone, "Europe/Stockholm")

    {:ok, time} = DateTime.shift_zone(time, timezone)

    Tiki.Cldr.DateTime.to_string!(time, format: format)
    |> String.capitalize()
  end

  def image_url(path, opts \\ [])
  def image_url(nil, _opts), do: nil

  def image_url(path, opts) do
    path = if path |> String.starts_with?("/"), do: path, else: "/" <> path

    width = Keyword.get(opts, :width, nil)
    height = Keyword.get(opts, :height, nil)

    Imgproxy.new(path)
    |> Imgproxy.set_extension("webp")
    |> Imgproxy.resize(width, height)
    |> to_string()
  end
end
