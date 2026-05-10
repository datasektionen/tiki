defmodule TikiWeb.RawBodyParser do
  @behaviour Plug

  def init(opts) do
    cache = Plug.Parsers.init([body_reader: {__MODULE__, :cache_raw_body, []}] ++ opts)
    nocache = Plug.Parsers.init(opts)
    {cache, nocache}
  end

  def call(%{path_info: ["stripe", "webhook"]} = conn, {cache, _nocache}) do
    Plug.Parsers.call(conn, cache)
  end

  def call(conn, {_cache, nocache}) do
    Plug.Parsers.call(conn, nocache)
  end

  @doc false
  def cache_raw_body(conn, opts) do
    with {:ok, body, conn} <- Plug.Conn.read_body(conn, opts) do
      conn = update_in(conn.assigns[:raw_body], &[body | &1 || []])
      {:ok, body, conn}
    end
  end
end
