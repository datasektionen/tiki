:ok = LocalCluster.start()

Application.stop(:logger)
Application.ensure_all_started(:tiki)

ExUnit.start(exclude: [cluster: true])
Ecto.Adapters.SQL.Sandbox.mode(Tiki.Repo, :manual)
