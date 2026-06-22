defmodule Mix.Tasks.DocsSite.Build do
  use Mix.Task

  require Logger

  @shortdoc "Builds the static docs site into _docs_site/"

  @impl Mix.Task
  def run(_args) do
    File.mkdir_p!("_docs_site/assets")
    Mix.Task.run("tailwind", ["docs", "--minify"])
    Mix.Task.run("compile", [])

    {micro, :ok} = :timer.tc(fn -> Tiki.Docs.build() end)
    Logger.info("Docs built in #{div(micro, 1000)}ms → _docs_site/")

    case Tiki.Docs.all_docs() do
      [first | _] ->
        File.write!("_docs_site/sws.toml", """
        [[advanced.redirects]]
        source = "/"
        destination = "/#{first.path}"
        kind = 302

        [[advanced.redirects]]
        source = "/index.html"
        destination = "/#{first.path}"
        kind = 302

        [[advanced.redirects]]
        source = "{**/*}.html"
        destination = "$1"
        kind = 302
        """)
    end
  end
end
