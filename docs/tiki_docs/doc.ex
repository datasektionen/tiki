defmodule Tiki.Docs.Doc do
  @enforce_keys [:id, :title, :body, :path]
  defstruct [:id, :title, :body, :path, :section, :section_order, :order, :description]

  def build(filename, attrs, body) do
    # Extract path relative to priv/docs/ directory
    [_, relative] = String.split(filename, "/priv/docs/", parts: 2)

    slug = Path.rootname(relative)
    segments = Path.split(slug)

    {derived_section, derived_section_order, page_slug, derived_order} =
      case segments do
        [page_slug] ->
          {nil, 0, page_slug, extract_order(page_slug)}

        [folder | _] ->
          page_slug = List.last(segments)

          {humanize(strip_prefix(folder)), extract_order(folder) || 0, page_slug,
           extract_order(page_slug)}
      end

    slug_path = Path.split(slug) |> Enum.map(&strip_prefix/1) |> Path.join()

    struct!(__MODULE__,
      id: slug,
      path: slug_path <> ".html",
      body: body,
      title: Map.get(attrs, :title) || humanize(strip_prefix(page_slug)),
      section: Map.get(attrs, :section, derived_section),
      section_order: derived_section_order,
      order: Map.get(attrs, :order) || derived_order,
      description: Map.get(attrs, :description)
    )
  end

  # "01-getting-started" → "getting-started"
  defp strip_prefix(name) do
    case Regex.run(~r/^\d+[-_](.+)$/, name) do
      [_, rest] -> rest
      _ -> name
    end
  end

  # "01-getting-started" → 1, "introduction" → nil
  defp extract_order(name) do
    case Regex.run(~r/^(\d+)[-_]/, name) do
      [_, n] -> String.to_integer(n)
      _ -> nil
    end
  end

  defp humanize(slug) do
    slug
    |> String.replace(["-", "_"], " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
