:ok = LocalCluster.start()

Application.stop(:logger)
Application.ensure_all_started(:tiki)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Tiki.Repo, :manual)
