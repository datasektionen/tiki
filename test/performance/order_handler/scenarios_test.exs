defmodule Tiki.Performance.OrderHandler.ScenariosTest do
  @moduledoc """
  Correctness tests for realistic multi-batch event scenarios.

  These complement the concurrency and noise tests (which stress a single
  batch) by verifying that the availability CTE correctly enforces capacity
  across multiple independent batches and shared parent pools.
  """

  use Tiki.PerformanceCase

  @moduletag :performance

  # ---------------------------------------------------------------------------
  # Multi-date: two independent batches
  # ---------------------------------------------------------------------------

  describe "multi-date event" do
    setup do
      scenario = Scenarios.multi_date()

      %{event: event, batches: batches, buyer_plan: plan, cleanup: cleanup} =
        setup_event(spec: scenario)

      on_exit(cleanup)
      %{event: event, batches: batches, buyer_plan: plan, scenario: scenario}
    end

    test "no overbooking in either batch under full load", %{
      event: event,
      batches: batches,
      buyer_plan: plan,
      scenario: scenario
    } do
      {micros, zipped, timings} = run_buyer_plan(event.id, plan)

      {_, results} = Enum.unzip(zipped)

      report(event.id, results,
        label: "scenarios/multi-date",
        capacity: scenario_capacity(scenario),
        micros: micros,
        timings: timings
      )

      verify_limits(event.id, batches)
    end

    test "friday sellout does not block saturday reservations", %{
      event: event,
      batches: batches
    } do
      %{batch: fri_batch, ticket_types: %{regular: fri_tt}} = batches["Friday"]
      %{ticket_types: %{regular: sat_tt}} = batches["Saturday"]

      {_, fri_results, _} = run_wave(event.id, fri_tt, fri_batch.max_size)
      fri_successes = Enum.count(fri_results, &match?({:ok, _}, &1))

      assert fri_successes == fri_batch.max_size,
             "Expected all #{fri_batch.max_size} Friday slots to fill, got #{fri_successes}"

      assert {:ok, _} = Orders.reserve_tickets(event.id, %{sat_tt.id => 1}, nil),
             "Saturday reservation failed after Friday sold out"

      assert count_active_tickets_in(event.id, batches["Friday"].ticket_types) ==
               fri_batch.max_size

      assert count_active_tickets_in(event.id, batches["Saturday"].ticket_types) == 1
    end
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
      batches: batches,
      buyer_plan: plan,
      scenario: scenario
    } do
      {micros, zipped, timings} = run_buyer_plan(event.id, plan)

      {_, results} = Enum.unzip(zipped)

      report(event.id, results,
        label: "scenarios/shared-pool",
        capacity: scenario_capacity(scenario),
        micros: micros,
        timings: timings
      )

      verify_limits(event.id, batches)
    end
  end
end
