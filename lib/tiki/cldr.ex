defmodule Tiki.Cldr do
  use Cldr,
    locales: ["en", "sv", "en_SE"],
    providers: [Cldr.Number, Cldr.Calendar, Cldr.DateTime],
    gettext: TikiWeb.Gettext

  def wrap_locale("sv"), do: "sv"
  def wrap_locale(_), do: "en_SE"
end
