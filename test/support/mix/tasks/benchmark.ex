defmodule Mix.Tasks.Benchmark do
  @moduledoc """
  Runs performance benchmarks against the test database and prints metrics.

      mix benchmark

  Optionally scale capacities via PERF_SCALE:

      PERF_SCALE=10 mix benchmark
  """

  use Mix.Task

  alias Tiki.Performance.Scenarios
  alias Tiki.PerformanceCase, as: Bench

  @shortdoc "Run performance benchmarks (MIX_ENV=test)"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")
    Ecto.Adapters.SQL.Sandbox.mode(Tiki.Repo, :auto)

    IO.puts("\n=== Benchmarks (PERF_SCALE=#{Bench.perf_scale()}) ===\n")

    run_scenario("single_batch / no noise", Scenarios.single_batch())

    run_scenario("single_batch / no noise", Scenarios.single_batch(), n_nodes: 2)

    run_scenario("single_batch / cancel noise (30%)", Scenarios.single_batch(), cancel_prob: 0.3)
    run_scenario("single_batch / pay noise (30%)", Scenarios.single_batch(), pay_prob: 0.3)

    run_scenario("single_batch / mixed noise (20%+20%)", Scenarios.single_batch(),
      cancel_prob: 0.2,
      pay_prob: 0.2
    )

    run_scenario("multi_date", Scenarios.multi_date())
    run_scenario("shared_pool", Scenarios.shared_pool())

    run_scenario("shared_pool / mixed noise (20%+20%)", Scenarios.shared_pool(),
      cancel_prob: 0.2,
      pay_prob: 0.2
    )

    run_scenario("shared_pool / mixed noise (20%+20%)", Scenarios.shared_pool(),
      cancel_prob: 0.2,
      pay_prob: 0.2,
      n_nodes: 2
    )

    IO.puts("=== Done ===\n")
  end

  defp run_scenario(label, spec, opts \\ []) do
    %{event: event, batches: batches, buyer_plan: plan, cleanup: cleanup} =
      Bench.setup_event(spec: spec)

    n_nodes = Keyword.get(opts, :n_nodes, 1)

    if n_nodes > 1 do
      :ok = LocalCluster.start()
      Application.ensure_all_started(:tiki)

      repo_config = Application.get_env(:tiki, Tiki.Repo, []) |> Keyword.put(:pool_size, 10)

      env = [
        tiki: [
          {Tiki.Repo, repo_config},
          {:metrics_port, 0}
        ]
      ]

      {:ok, cluster} = LocalCluster.start_link(n_nodes, environment: env)

      nodes =
        case LocalCluster.nodes(cluster) do
          {:ok, n} -> n
          n when is_list(n) -> n
        end

      Enum.each(nodes, fn node ->
        :rpc.call(node, Ecto.Adapters.SQL.Sandbox, :mode, [Tiki.Repo, :auto])
      end)

      Enum.map(nodes, fn node ->
        Task.async(fn ->
          :rpc.call(node, Bench, :run_buyer_plan, [event.id, plan, opts])
        end)
      end)
      |> Task.await_many()
      |> Enum.with_index()
      |> Enum.map(fn {{micros, zipped, timings}, node} ->
        {_, results} = Enum.unzip(zipped)

        Bench.print_metrics(event.id, results,
          label: "multinode / node #{node + 1} / #{label}",
          capacity: Bench.scenario_capacity(spec),
          micros: micros,
          timings: timings
        )

        Bench.print_limits(event.id, batches)
        IO.puts("")
      end)

      LocalCluster.stop(cluster)
    else
      {micros, zipped, timings} = Bench.run_buyer_plan(event.id, plan, opts)
      {_, results} = Enum.unzip(zipped)

      Bench.print_metrics(event.id, results,
        label: label,
        capacity: Bench.scenario_capacity(spec),
        micros: micros,
        timings: timings
      )

      Bench.print_limits(event.id, batches)
      IO.puts("")
    end

    cleanup.()
  end
end
