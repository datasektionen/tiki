defmodule Tiki.Performance.OrderHandler.NoiseTest do
  @moduledoc """
  Concurrency tests with per-buyer noise: after a successful reservation each
  buyer independently rolls the dice and may immediately cancel or pay.

  Scale is controlled via PERF_SCALE (multiplies scenario base capacity of 10):

      mix test --only performance               # PERF_SCALE=1  → capacity 10
      PERF_SCALE=50 mix test --only performance  # PERF_SCALE=50 → capacity 500
  """

  use Tiki.PerformanceCase

  @moduletag :performance

  setup do
    scenario = Scenarios.single_batch()

    %{
      event: event,
      batches: batches,
      buyer_plan: plan,
      cleanup: cleanup
    } =
      setup_event(spec: scenario)

    %{batch: batch} = batches["General"]
    on_exit(cleanup)
    %{event: event, buyer_plan: plan, capacity: batch.max_size}
  end

  test "no overbooking with cancellation noise", %{
    event: event,
    buyer_plan: plan,
    capacity: capacity
  } do
    {micros, zipped, timings} =
      run_buyer_plan(event.id, plan, cancel_prob: 0.3)

    noise_report(event.id, zipped, timings,
      label: "noise/cancel",
      capacity: capacity,
      micros: micros
    )
  end

  test "no overbooking with payment noise", %{
    event: event,
    buyer_plan: plan,
    capacity: capacity
  } do
    {micros, zipped, timings} =
      run_buyer_plan(event.id, plan, pay_prob: 0.3)

    noise_report(event.id, zipped, timings,
      label: "noise/pay",
      capacity: capacity,
      micros: micros
    )
  end

  test "no overbooking with mixed cancellation and payment noise", %{
    event: event,
    buyer_plan: plan,
    capacity: capacity
  } do
    {micros, zipped, timings} =
      run_buyer_plan(event.id, plan, cancel_prob: 0.2, pay_prob: 0.2)

    noise_report(event.id, zipped, timings,
      label: "noise/mixed",
      capacity: capacity,
      micros: micros
    )
  end

  describe "shared pool event" do
    setup do
      scenario = Scenarios.shared_pool()

      %{event: event, batches: batches, buyer_plan: plan, cleanup: cleanup} =
        setup_event(spec: scenario)

      on_exit(cleanup)
      %{event: event, batches: batches, buyer_plan: plan, scenario: scenario}
    end

    test "no overbooking in any batch under full load", %{
      event: event,
      buyer_plan: plan,
      scenario: scenario
    } do
      {micros, zipped, timings} = run_buyer_plan(event.id, plan, pay_prob: 0.2, cancel_prob: 0.2)

      noise_report(event.id, zipped, timings,
        label: "noise/shared-pool",
        capacity: scenario_capacity(scenario),
        micros: micros,
        timings: timings
      )
    end

    test "multinode shared pool", %{
      event: event,
      buyer_plan: plan,
      scenario: scenario
    } do
      :ok = LocalCluster.start()
      Application.ensure_all_started(:tiki)

      n_nodes = 2

      repo_config = Application.get_env(:tiki, Tiki.Repo, []) |> Keyword.put(:pool_size, 2)

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
          :rpc.call(node, Tiki.PerformanceCase, :run_buyer_plan, [
            event.id,
            plan,
            [pay_prob: 0.2, cancel_prob: 0.2]
          ])
        end)
      end)
      |> Task.await_many()
      |> Enum.with_index()
      |> Enum.map(fn {{micros, zipped, timings}, node} ->
        noise_report(event.id, zipped, timings,
          label: "multinode/noise/shared-pool/node #{node + 1}",
          capacity: scenario_capacity(scenario),
          micros: micros,
          timings: timings
        )
      end)

      LocalCluster.stop(cluster)
    end
  end

  # Noise tests have a weaker invariant than report/3: db_count can be lower
  # than successes because buyers cancel/pay after reserving.
  defp noise_report(event_id, _zipped, _timings, opts) do
    capacity = Keyword.fetch!(opts, :capacity)
    db_count = count_active_tickets(event_id)

    assert db_count <= capacity,
           "DB shows #{db_count} active tickets but capacity is #{capacity}"
  end
end
