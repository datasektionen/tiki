defmodule Tiki.Docs do
  use NimblePublisher,
    build: Tiki.Docs.Doc,
    from: Application.app_dir(:tiki, "priv/docs/**/*.md"),
    as: :docs,
    html_converter: NimblePublisherMDEx,
    mdex_opts: [extension: [header_id_prefix: ""]]

  @output_dir "_docs_site"

  @docs Enum.sort_by(
          @docs,
          &{&1.section_order || 0, &1.section || "", &1.order || 999, &1.title || ""}
        )

  def all_docs, do: @docs

  def build do
    File.mkdir_p!(Path.join(@output_dir, "assets"))

    nav = build_nav(@docs)

    for {doc, index} <- Enum.with_index(@docs) do
      prev = if index > 0, do: Enum.at(@docs, index - 1)
      next = Enum.at(@docs, index + 1)
      out_path = Path.join(@output_dir, doc.path)
      File.mkdir_p!(Path.dirname(out_path))

      rendered =
        Tiki.Docs.Layout.page(%{doc: doc, nav_sections: nav, prev_doc: prev, next_doc: next})

      html = rendered |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()
      File.write!(out_path, html)
    end

    :ok
  end

  defp build_nav(docs) do
    docs
    |> Enum.group_by(& &1.section)
    |> Enum.map(fn {section, section_docs} ->
      sorted = Enum.sort_by(section_docs, &{&1.order || 999, &1.title || ""})
      {section, sorted}
    end)
    |> Enum.sort_by(fn {_, [first | _]} -> {first.section_order || 0, first.section || ""} end)
  end
end
