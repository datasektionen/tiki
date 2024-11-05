defmodule Tiki.Cldr do
  use Cldr,
    providers: [Cldr.Number, Cldr.Calendar, Cldr.DateTime],
    gettext: TikiWeb.Gettext
end
