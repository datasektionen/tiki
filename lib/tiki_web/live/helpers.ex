defmodule TikiWeb.LiveHelpers do
  use Phoenix.LiveView

  def assign_breadcrumbs(socket, crumbs) do
    # Translate the crumbs
    crumbs =
      Enum.map(crumbs, fn {label, url} -> {Gettext.gettext(TikiWeb.Gettext, label || ""), url} end)

    assign(socket, breadcrumbs: crumbs)
  end

  def time_to_string(time, opts \\ [])
  def time_to_string(nil, _opts), do: ""

  # convert date to datetime
  def time_to_string(%Date{} = date, _opts) do
    date
    |> Date.to_gregorian_days()
    |> Kernel.*(86400)
    |> Kernel.+(86399)
    |> DateTime.from_gregorian_seconds()
  end

  def time_to_string(%NaiveDateTime{} = time, opts) do
    DateTime.from_naive!(time, "Etc/UTC")
    |> time_to_string(opts)
  end

  def time_to_string(time, opts) do
    format = Keyword.get(opts, :format, :yMMMEd)
    timezone = Keyword.get(opts, :timezone, "Europe/Stockholm")
    locale = Keyword.get(opts, :locale, nil)

    {:ok, time} = DateTime.shift_zone(time, timezone)

    cldr_opts = [format: format]
    cldr_opts = if locale, do: [locale: locale] ++ cldr_opts, else: cldr_opts

    Tiki.Cldr.DateTime.to_string!(time, cldr_opts)
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

  def format_sek(amount, opts \\ []) do
    locale = Keyword.get(opts, :locale, Gettext.get_locale(TikiWeb.Gettext))
    currency_digits = Keyword.get(opts, :currency_digits, :cash)

    Tiki.Cldr.Number.to_string!(amount,
      locale: locale,
      currency_digits: currency_digits,
      currency: "SEK"
    )
  end
end
