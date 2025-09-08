defprotocol Tiki.Localization do
  def localize(data, language)
end

defimpl Tiki.Localization, for: List do
  def localize(list, language) do
    Enum.map(list, &Tiki.Localization.localize(&1, language))
  end
end

defmodule Tiki.Localizer do
  alias Tiki.Localization

  def localize(data), do: Localization.localize(data, Gettext.get_locale(TikiWeb.Gettext))
  def localize(data, language), do: Localization.localize(data, language)
end
