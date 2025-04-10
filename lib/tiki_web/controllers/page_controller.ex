defmodule TikiWeb.PageController do
  use TikiWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  def about(conn, _params) do
    render(conn, :about)
  end

  def terms(conn, _params) do
    render(conn, :terms)
  end
end
