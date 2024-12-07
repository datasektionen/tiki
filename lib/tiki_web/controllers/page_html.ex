defmodule TikiWeb.PageHTML do
  use TikiWeb, :html

  import TikiWeb.Layouts, only: [nav: 1, footer: 1]

  embed_templates "page_html/*"
end
