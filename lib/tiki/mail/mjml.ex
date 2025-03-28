defmodule Tiki.Mail.Mjml do
  @moduledoc """
  Helper module for generating MJML emails from LiveView components.
  """

  @doc """
  Renders a LiveView component including mjml to a raw html string.
  """
  def to_html(component) do
    case component
         |> Phoenix.HTML.Safe.to_iodata()
         |> to_string()
         |> Mjml.to_html() do
      {:ok, html} -> {:ok, String.replace(html, "<!doctype html>", "")}
      err -> err
    end
  end
end
