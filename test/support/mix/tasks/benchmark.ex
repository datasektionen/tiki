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

    IO.puts("=== Done ===\n")
  end

  defp run_scenario(label, spec, noise_opts \\ []) do
    %{event: event, batches: batches, buyer_plan: plan, cleanup: cleanup} =
      Bench.setup_event(spec: spec)

    {micros, zipped, timings} = Bench.run_buyer_plan(event.id, plan, noise_opts)
    {_, results} = Enum.unzip(zipped)

    Bench.print_metrics(event.id, results,
      label: label,
      capacity: Bench.scenario_capacity(spec),
      micros: micros,
      timings: timings
    )

    Bench.print_limits(event.id, batches)
    IO.puts("")

    cleanup.()
  end
end
