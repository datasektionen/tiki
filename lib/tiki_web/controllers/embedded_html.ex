defmodule TikiWeb.EmbeddedHTML do
  use TikiWeb, :html

  def render("close.html", assigns) do
    ~H"""
    <script>
      window.parent.postMessage({ type: "close" }, "*");
    </script>
    """
  end
end
